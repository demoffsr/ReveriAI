import SwiftUI
import SwiftData
import AVFoundation
import os

@Observable
final class RecordViewModel {
    private static let logger = Logger(subsystem: "com.reveri", category: "RecordVM")
    enum Mode {
        case voice
        case text
    }

    enum RecordState {
        case idle
        case typing
        case saved
    }

    var mode: Mode = .voice
    var state: RecordState = .idle
    var dreamText: String = ""
    var selectedEmotions: [DreamEmotion] = []
    var speechLocaleRaw: String = SpeechLocale.defaultLocale.rawValue
    var savedDream: Dream?
    var onDreamSaved: ((Dream) -> Void)?
    var onShowHowDidItFeel: (() -> Void)?

    var canSave: Bool {
        !dreamText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    func saveDream(context: ModelContext) -> Bool {
        guard canSave else { return false }
        let dream = Dream(text: dreamText.trimmingCharacters(in: .whitespacesAndNewlines), emotions: selectedEmotions)
        context.insert(dream)
        do {
            try context.save()
        } catch {
            Self.logger.error("Failed to save text dream: \(error.localizedDescription)")
            context.rollback()
            HapticService.notification(.error)
            return false
        }
        HapticService.notification(.success)

        AnalyticsService.track(.dreamRecorded, metadata: [
            "mode": "text",
            "text_length": dream.text.count,
            "has_emotions": !selectedEmotions.isEmpty,
            "emotion_count": selectedEmotions.count
        ])

        DreamAIService.generateTitleInBackground(
            dreamID: dream.persistentModelID,
            dreamText: dream.text,
            locale: SpeechLocale(rawValue: speechLocaleRaw) ?? .russian,
            modelContainer: context.container
        )

        savedDream = dream
        onDreamSaved?(dream)
        dreamText = ""
        state = .saved
        NotificationService.removeDeliveredNotifications()
        onShowHowDidItFeel?()
        return true
    }

    private static let recordingsDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
    }()

    @discardableResult
    func saveAudioDream(audioPath: String, transcript: String = "", context: ModelContext) -> Bool {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        var duration: TimeInterval?
        let audioURL = Self.recordingsDirectory.appendingPathComponent(audioPath)
        if let player = try? AVAudioPlayer(contentsOf: audioURL) {
            duration = player.duration
        }

        let dream = Dream(
            text: trimmedTranscript,
            emotions: selectedEmotions,
            audioFilePath: audioPath,
            originalTranscript: trimmedTranscript.isEmpty ? nil : trimmedTranscript,
            audioDuration: duration
        )
        context.insert(dream)
        do {
            try context.save()
        } catch {
            Self.logger.error("Failed to save audio dream: \(error.localizedDescription)")
            context.rollback()
            HapticService.notification(.error)
            return false
        }
        HapticService.notification(.success)

        AnalyticsService.track(.reviewSavedAudio, metadata: [
            "has_transcript": !trimmedTranscript.isEmpty,
            "transcript_length": trimmedTranscript.count,
            "duration_seconds": duration ?? 0,
            "has_emotions": !selectedEmotions.isEmpty
        ])

        let locale = SpeechLocale(rawValue: speechLocaleRaw) ?? .russian

        // Title from live captions (will be overwritten after Whisper if empty)
        if !trimmedTranscript.isEmpty {
            DreamAIService.generateTitleInBackground(
                dreamID: dream.persistentModelID,
                dreamText: trimmedTranscript,
                locale: locale,
                modelContainer: context.container
            )
        }

        // Whisper transcription in background
        Self.logger.info("🎙️ saveAudioDream: audioPath=\(audioPath), transcriptLength=\(trimmedTranscript.count), hasOriginalTranscript=\(dream.originalTranscript != nil)")
        DreamAIService.transcribeAudioInBackground(
            dreamID: dream.persistentModelID,
            audioFileName: audioPath,
            locale: locale,
            modelContainer: context.container
        )

        savedDream = dream
        onDreamSaved?(dream)
        state = .saved
        NotificationService.removeDeliveredNotifications()
        onShowHowDidItFeel?()
        return true
    }

    func reset() {
        state = .idle
        selectedEmotions = []
        savedDream = nil
    }
}
