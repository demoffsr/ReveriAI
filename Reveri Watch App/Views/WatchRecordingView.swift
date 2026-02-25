import SwiftUI

struct WatchRecordingView: View {
    @Environment(WatchSessionManager.self) private var sessionManager
    @Environment(WatchThemeManager.self) private var theme
    @State private var recorder = WatchAudioRecorder()
    @State private var showEmotionPicker = false
    @State private var recordedAudioURL: URL?
    @State private var recordedCreatedAt: Date?
    @State private var waveformState = WatchWaveformState()

    var body: some View {
        NavigationStack {
            ZStack {
                // Cosmic background
                Image("BackgroundDaylight")
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.55))
                    .ignoresSafeArea()

                GeometryReader { geo in
                    if recorder.isRecording {
                        recordingContent
                            .frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        idleContent
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
            .navigationTitle(recorder.isRecording ? "Recording" : "Reveri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarForegroundStyle(theme.accent, for: .automatic)
            .navigationDestination(isPresented: $showEmotionPicker) {
                WatchEmotionPickerView { emotion in
                    sendToPhone(emotion: emotion)
                }
                .environment(theme)
            }
        }
    }

    // MARK: - Idle

    private var idleContent: some View {
        VStack {
            Spacer()

            WatchRecordButton(accent: theme.accent) {
                startRecording()
            }

            Spacer()

            Text("Tap to Record")
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 4)
        }
    }

    // MARK: - Recording

    private var recordingContent: some View {
        VStack(spacing: 12) {
            Spacer()

            WatchLiveWaveformView(
                recorder: recorder,
                waveformState: waveformState,
                accentColor: theme.accent
            )

            Text(formatDuration(recorder.duration))
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)

            Spacer()

            Button {
                stopRecording()
            } label: {
                Text("Stop")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .handGestureShortcut(.primaryAction)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Actions

    private func startRecording() {
        waveformState.reset()
        try? recorder.startRecording()
    }

    private func stopRecording() {
        recorder.stopRecording()
        recordedAudioURL = recorder.audioFileURL
        recordedCreatedAt = Date()
        showEmotionPicker = true
    }

    private func sendToPhone(emotion: DreamEmotion?) {
        guard let url = recordedAudioURL,
              let createdAt = recordedCreatedAt else { return }
        let emotions = emotion.map { [$0.rawValue] } ?? []
        sessionManager.transferAudioFile(url: url, createdAt: createdAt, emotions: emotions)
        recordedAudioURL = nil
        recordedCreatedAt = nil
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Observation Isolation

/// Small wrapper that isolates observation of `recorder.currentLevel` (~10Hz updates)
/// so the parent `WatchRecordingView` body doesn't re-evaluate on every metering tick.
private struct WatchLiveWaveformView: View {
    let recorder: WatchAudioRecorder
    let waveformState: WatchWaveformState
    let accentColor: Color

    var body: some View {
        WatchScrollingWaveformView(
            isAnimating: recorder.isRecording,
            level: recorder.currentLevel,
            waveformState: waveformState,
            accentColor: accentColor
        )
    }
}
