import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Waveform Widget

private struct LiveWaveformWidget: View {
    let levels: [Float]
    let levelStartIndex: Int
    let isPaused: Bool
    let palette: WidgetPalette

    private static let barWidth: CGFloat = 4
    private static let barSpacing: CGFloat = 3.628
    private static let minHeight: CGFloat = 6
    private static let maxHeight: CGFloat = 62
    private static let visibleBars = 27

    var body: some View {
        let displayLevels = Array(levels.suffix(Self.visibleBars))

        HStack(alignment: .center, spacing: Self.barSpacing) {
            ForEach(0..<Self.visibleBars, id: \.self) { position in
                let isReal = position < displayLevels.count
                let level = isReal ? CGFloat(displayLevels[position]) : 0
                let height = Self.minHeight + level * (Self.maxHeight - Self.minHeight)

                Capsule()
                    .fill(isReal ? palette.accent : Color.white.opacity(0.25))
                    .frame(width: Self.barWidth, height: height)
            }
        }
        .frame(width: 209, height: Self.maxHeight)
        .opacity(isPaused ? 0.4 : 1.0)
        .mask(
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 30)
                Color.white
            }
        )
    }
}

// MARK: - Widget

struct RecordingActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            lockScreenBanner(context: context)
        } dynamicIsland: { context in
            dynamicIslandConfig(context: context)
        }
    }

    // MARK: Lock Screen Banner

    private func lockScreenBanner(context: ActivityViewContext<RecordingActivityAttributes>) -> some View {
        let palette = WidgetPalette.current

        return HStack {
            LiveWaveformWidget(
                levels: context.state.levels,
                levelStartIndex: context.state.levelStartIndex,
                isPaused: context.state.isPaused,
                palette: palette
            )

            Spacer()

            HStack(spacing: 12) {
                timerView(context.state)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Link(destination: URL(string: "reveri://stop-recording")!) {
                    Image("StopIconLock")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .frame(width: 44, height: 44)
                        .background(Color(red: 1, green: 63 / 255, blue: 66 / 255).opacity(0.2), in: Circle())
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .white.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            ZStack {
                LinearGradient(
                    colors: [palette.gradientStart, palette.gradientEnd],
                    startPoint: UnitPoint(x: 0.1, y: 0),
                    endPoint: UnitPoint(x: 0.9, y: 1)
                )

                Image("NoiseTexture")
                    .resizable(resizingMode: .tile)
                    .opacity(0.5)
                    .blendMode(.hardLight)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
        .activityBackgroundTint(.clear)
    }

    // MARK: Dynamic Island

    private func dynamicIslandConfig(context: ActivityViewContext<RecordingActivityAttributes>) -> DynamicIsland {
        let palette = WidgetPalette.current

        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                Image(systemName: "waveform")
                    .foregroundStyle(palette.accent)
            }
            DynamicIslandExpandedRegion(.center) {
                timerView(context.state)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundStyle(.white)
            }
            DynamicIslandExpandedRegion(.trailing) {
                Link(destination: URL(string: "reveri://stop-recording")!) {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(.red)
                }
            }
        } compactLeading: {
            Image(systemName: "waveform")
                .foregroundStyle(palette.accent)
        } compactTrailing: {
            timerView(context.state)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white)
        } minimal: {
            Image(systemName: "waveform")
                .foregroundStyle(palette.accent)
        }
    }

    // MARK: Timer

    @ViewBuilder
    private func timerView(_ state: RecordingActivityAttributes.ContentState) -> some View {
        if state.isPaused {
            Text(formatTime(state.pausedElapsedSeconds))
                .monospacedDigit()
        } else {
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
