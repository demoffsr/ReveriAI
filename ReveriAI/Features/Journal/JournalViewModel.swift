import SwiftUI

@Observable
final class JournalViewModel {
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case thisWeek = "This week"
        case thisMonth = "This month"
    }

    var selectedTimeRange: TimeRange = .today
    var selectedEmotion: DreamEmotion?
    var searchText: String = ""

    func matches(_ dream: Dream) -> Bool {
        // Time range filter
        let passesTime: Bool = switch selectedTimeRange {
        case .today: dream.createdAt.isToday
        case .thisWeek: dream.createdAt.isThisWeek
        case .thisMonth: dream.createdAt.isThisMonth
        }

        guard passesTime else { return false }

        // Emotion filter
        if let emotion = selectedEmotion, dream.emotion != emotion {
            return false
        }

        // Search filter
        if !searchText.isEmpty {
            let lowered = searchText.lowercased()
            if !dream.text.lowercased().contains(lowered) {
                return false
            }
        }

        return true
    }

    func clearEmotionFilter() {
        selectedEmotion = nil
    }
}
