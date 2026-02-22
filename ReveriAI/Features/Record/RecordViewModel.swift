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
        let dream = Dream(text: transcript, emotions: selectedEmotions, audioFilePath: audioPath)
        context.insert(dream)
        try? context.save()
        HapticService.notification(.success)

        if !transcript.isEmpty {
            DreamAIService.generateTitleInBackground(
                dreamID: dream.persistentModelID,
                dreamText: transcript,
                locale: SpeechLocale(rawValue: speechLocaleRaw) ?? .russian,
                modelContainer: context.container
            )
        }

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
