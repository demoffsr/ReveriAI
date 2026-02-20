import ActivityKit
import Foundation
import Observation

@Observable
final class LiveActivityManager {
    private var activity: Activity<RecordingActivityAttributes>?

    func startRecording() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = RecordingActivityAttributes.ContentState(
            isPaused: false,
            recordingStartDate: .now,
            pausedElapsedSeconds: 0
        )
        do {
            activity = try Activity.request(
                attributes: RecordingActivityAttributes(),
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("LiveActivityManager: start failed — \(error)")
        }
    }

    func pause(elapsedSeconds: Int) {
        let state = RecordingActivityAttributes.ContentState(
            isPaused: true,
            recordingStartDate: .now,
            pausedElapsedSeconds: elapsedSeconds
        )
        Task { await activity?.update(.init(state: state, staleDate: nil)) }
    }

    func resume(elapsedSeconds: Int) {
        let state = RecordingActivityAttributes.ContentState(
            isPaused: false,
            recordingStartDate: .now,
            pausedElapsedSeconds: elapsedSeconds
        )
        Task { await activity?.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        Task {
            let state = RecordingActivityAttributes.ContentState(
                isPaused: false,
                recordingStartDate: .now,
                pausedElapsedSeconds: 0
            )
            await activity?.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            activity = nil
        }
    }
}
