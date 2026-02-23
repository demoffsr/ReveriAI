import ActivityKit
import Foundation

struct RecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var recordingStartDate: Date
        /// Total elapsed recording seconds (updated every ~1s via state push)
        var elapsedSeconds: Int
        /// Rolling window of normalized audio levels (0...1) for waveform display
        var levels: [Float] = []
        /// Absolute index of levels[0] — used for stable ForEach IDs to animate scrolling
        var levelStartIndex: Int = 0
    }
}
