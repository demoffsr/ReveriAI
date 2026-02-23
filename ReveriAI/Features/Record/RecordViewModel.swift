import SwiftUI
import SwiftData

@Observable
final class RecordViewModel {
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

    func saveDream(context: ModelContext) {
        guard canSave else { return }
        let dream = Dream(text: dreamText.trimmingCharacters(in: .whitespacesAndNewlines), emotions: selectedEmotions)
        context.insert(dream)
        try? context.save()
        HapticService.notification(.success)

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
    }

    func saveAudioDream(audioPath: String, transcript: String = "", context: ModelContext) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let dream = Dream(
            text: trimmedTranscript,
            emotions: selectedEmotions,
            audioFilePath: audioPath,
            originalTranscript: trimmedTranscript.isEmpty ? nil : trimmedTranscript
        )
        context.insert(dream)
        try? context.save()
        HapticService.notification(.success)

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
    }

    func reset() {
        state = .idle
        selectedEmotions = []
        savedDream = nil
    }
}
