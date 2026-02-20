import ActivityKit
import SwiftUI
import WidgetKit

struct RecordingActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // Lock screen banner
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(.orange)
                Text("Recording Dream")
                    .font(.headline)
                Spacer()
                timerView(context.state)
                Circle()
                    .fill(context.state.isPaused ? .yellow : .red)
                    .frame(width: 8, height: 8)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "waveform")
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.center) {
                    timerView(context.state)
                        .font(.system(.title2, design: .monospaced))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                        .foregroundStyle(.orange)
                }
            } compactLeading: {
                Image(systemName: "waveform")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                timerView(context.state)
                    .font(.system(.caption, design: .monospaced))
            } minimal: {
                Image(systemName: "waveform")
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func timerView(_ state: RecordingActivityAttributes.ContentState) -> some View {
        if state.isPaused {
            // Static: show accumulated time
            Text(formatTime(state.pausedElapsedSeconds))
                .monospacedDigit()
        } else {
            // System-driven timer: counts up from adjusted start date
            Text(
                state.recordingStartDate
                    .addingTimeInterval(TimeInterval(-state.pausedElapsedSeconds)),
                style: .timer
            )
            .monospacedDigit()
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
