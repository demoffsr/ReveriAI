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
    var showToast: Bool = false
    var showHowDidItFeel: Bool = false
    var savedDream: Dream?

    var canSave: Bool {
        !dreamText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveDream(context: ModelContext) {
        guard canSave else { return }
        let dream = Dream(text: dreamText.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(dream)
        try? context.save()

        savedDream = dream
        dreamText = ""
        state = .saved
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            self?.showHowDidItFeel = true
        }
    }

    func reset() {
        state = .idle
        showHowDidItFeel = false
        savedDream = nil
    }

    func dismissHowDidItFeel() {
        showHowDidItFeel = false
    }
}
