import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case record
    case journal

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .record: "moon.stars.fill"
        case .journal: "book.fill"
        }
    }

    var label: String {
        switch self {
        case .record: "Record"
        case .journal: "Journal"
        }
    }
}
