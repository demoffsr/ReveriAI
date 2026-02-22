import ActivityKit
import Foundation

struct DreamReminderAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String  // "sleeping" / "wakeUp"
    }

    var startTime: Date
}
