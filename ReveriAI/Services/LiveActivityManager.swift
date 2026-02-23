import ActivityKit
import Foundation
import Observation

@Observable
final class LiveActivityManager {
    private var activity: Activity<RecordingActivityAttributes>?
    private var levelBuffer: [Float] = []
    private var smoothedLevel: Float = 0
    private var sampleTask: Task<Void, Never>?
    private var totalBarsAdded: Int = 0
    private var recordingStartDate: Date?
    private static let maxBars = 40

    // MARK: - Level Sampling

    func startLevelSampling(audioRecorder: AudioRecorder) {
        sampleTask?.cancel()
        levelBuffer = []
        smoothedLevel = 0
        totalBarsAdded = 0
        sampleTask = Task { @MainActor [weak audioRecorder] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let audioRecorder else { break }
                let target = max(0, min(1, audioRecorder.currentLevel))
                if target > self.smoothedLevel {
                    self.smoothedLevel = self.smoothedLevel * 0.3 + target * 0.7
                } else {
                    self.smoothedLevel = self.smoothedLevel * 0.8 + target * 0.2
                }
                self.levelBuffer.append(self.smoothedLevel)
                self.totalBarsAdded += 1
                if self.levelBuffer.count > Self.maxBars {
                    self.levelBuffer.removeFirst(self.levelBuffer.count - Self.maxBars)
                }
            }
        }
    }

    func stopLevelSampling() {
        sampleTask?.cancel()
        sampleTask = nil
    }

    func updateLevels(elapsedSeconds: Int) {
        guard let activity else { return }
        let startIndex = max(0, totalBarsAdded - levelBuffer.count)
        let state = RecordingActivityAttributes.ContentState(
            isPaused: false,
            recordingStartDate: recordingStartDate ?? .now,
            elapsedSeconds: elapsedSeconds,
            levels: levelBuffer,
            levelStartIndex: startIndex
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    // MARK: - Activity Lifecycle

    func startRecording() {
        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else { return }
        recordingStartDate = .now
        let state = RecordingActivityAttributes.ContentState(
            isPaused: false,
            recordingStartDate: recordingStartDate!,
            elapsedSeconds: 0
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
        stopLevelSampling()
        let startIndex = max(0, totalBarsAdded - levelBuffer.count)
        let state = RecordingActivityAttributes.ContentState(
            isPaused: true,
            recordingStartDate: recordingStartDate ?? .now,
            elapsedSeconds: elapsedSeconds,
            levels: levelBuffer,
            levelStartIndex: startIndex
        )
        Task { await activity?.update(.init(state: state, staleDate: nil)) }
    }

    func resume(elapsedSeconds: Int) {
        let startIndex = max(0, totalBarsAdded - levelBuffer.count)
        let state = RecordingActivityAttributes.ContentState(
            isPaused: false,
            recordingStartDate: recordingStartDate ?? .now,
            elapsedSeconds: elapsedSeconds,
            levels: levelBuffer,
            levelStartIndex: startIndex
        )
        Task { await activity?.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        stopLevelSampling()
        levelBuffer = []
        totalBarsAdded = 0
        recordingStartDate = nil
        Task {
            let state = RecordingActivityAttributes.ContentState(
                isPaused: false,
                recordingStartDate: .now,
                elapsedSeconds: 0
            )
            await activity?.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            activity = nil
        }
    }
}
