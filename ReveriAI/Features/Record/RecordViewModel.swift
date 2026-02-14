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

        savedDream = dream
        onDreamSaved?(dream)
        dreamText = ""
        state = .saved
        onShowHowDidItFeel?()
    }

    func saveAudioDream(audioPath: String, transcript: String = "", context: ModelContext) {
        let dream = Dream(text: transcript, emotions: selectedEmotions, audioFilePath: audioPath)
        context.insert(dream)
        try? context.save()

        savedDream = dream
        onDreamSaved?(dream)
        state = .saved
        onShowHowDidItFeel?()
    }

    func reset() {
        state = .idle
        selectedEmotions = []
        savedDream = nil
    }
}
