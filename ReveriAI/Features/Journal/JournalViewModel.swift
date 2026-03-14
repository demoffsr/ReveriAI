import SwiftUI

@Observable
final class JournalViewModel {
    enum TimeRange: String, CaseIterable {
        case today
        case thisWeek
        case thisMonth
        case allTime

        var displayName: String {
            switch self {
            case .today: String(localized: "timeRange.today", defaultValue: "Today")
            case .thisWeek: String(localized: "timeRange.thisWeek", defaultValue: "This week")
            case .thisMonth: String(localized: "timeRange.thisMonth", defaultValue: "This month")
            case .allTime: String(localized: "timeRange.allTime", defaultValue: "All time")
            }
        }
    }

    var selectedTimeRange: TimeRange = .allTime
    var selectedEmotion: DreamEmotion?
    var searchText: String = ""
    private(set) var filteredDreams: [Dream] = []

    func updateFilters(allDreams: [Dream]) {
        filteredDreams = allDreams.filter { matches($0) }
    }

    private func matches(_ dream: Dream) -> Bool {
        // Exclude archived dreams
        guard !dream.isArchived else { return false }

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
            let matchesText = dream.text.localizedCaseInsensitiveContains(searchText)
            let matchesTitle = !dream.title.isEmpty && dream.title.localizedCaseInsensitiveContains(searchText)
            if !matchesText && !matchesTitle {
                return false
            }
        }

        return true
    }

    func clearEmotionFilter() {
        selectedEmotion = nil
    }

    // MARK: - Search Overlay

    func searchDreams(in dreams: [Dream], query: String) -> [Dream] {
        guard !query.isEmpty else { return [] }
        return dreams.filter { dream in
            let matchesText = dream.text.localizedCaseInsensitiveContains(query)
            let matchesTitle = !dream.title.isEmpty && dream.title.localizedCaseInsensitiveContains(query)
            return matchesText || matchesTitle
        }
    }

    func searchFolders(in folders: [DreamFolder], query: String) -> [DreamFolder] {
        guard !query.isEmpty else { return [] }
        return folders.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}
