import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case record
    case journal

    var id: String { rawValue }

    var activeIcon: String {
        switch self {
        case .record: "MoonIconActive"
        case .journal: "JournalIconActive"
        }
    }

    var inactiveIcon: String {
        switch self {
        case .record: "MoonIconInactive"
        case .journal: "JournalIconInactive"
        }
    }

    var label: String {
        switch self {
        case .record: String(localized: "tab.record", defaultValue: "Record")
        case .journal: String(localized: "tab.journal", defaultValue: "Journal")
        }
    }
}
