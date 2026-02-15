import SwiftUI

@Observable
final class JournalViewModel {
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case thisWeek = "This week"
        case thisMonth = "This month"
        case allTime = "All time"
    }

    var selectedTimeRange: TimeRange = .allTime
    var selectedEmotion: DreamEmotion?
    var searchText: String = ""
    private(set) var filteredDreams: [Dream] = []

    func updateFilters(allDreams: [Dream]) {
        filteredDreams = allDreams.filter { matches($0) }
    }

    private func matches(_ dream: Dream) -> Bool {
        // Time range filter
        let passesTime: Bool = switch selectedTimeRange {
        case .today: dream.createdAt.isToday
        case .thisWeek: dream.createdAt.isThisWeek
        case .thisMonth: dream.createdAt.isThisMonth
        case .allTime: true
        }

        guard passesTime else { return false }

        // Emotion filter
        if let emotion = selectedEmotion {
            let matchesNew = dream.emotionValues.contains(emotion.rawValue)
            let matchesLegacy = dream.emotionRawValue == emotion.rawValue
            if !matchesNew && !matchesLegacy {
                return false
            }
        }

        // Search filter
        if !searchText.isEmpty {
            if !dream.text.localizedCaseInsensitiveContains(searchText) {
                return false
            }
        }

        return true
    }

    func clearEmotionFilter() {
        selectedEmotion = nil
    }
}
