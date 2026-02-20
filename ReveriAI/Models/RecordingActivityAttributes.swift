import ActivityKit
import Foundation

struct RecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var recordingStartDate: Date
        /// Accumulated seconds before current pause/resume cycle
        var pausedElapsedSeconds: Int
    }
}
