import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Live Waveform Widget (iPhone — 27 bars)

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
        .frame(width: 202, height: Self.maxHeight)
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

// MARK: - Watch Waveform Widget (12 bars)

private struct WatchWaveformWidget: View {
    let levels: [Float]
    let isPaused: Bool
    let palette: WidgetPalette

    private static let barWidth: CGFloat = 3
    private static let barSpacing: CGFloat = 2.5
    private static let minHeight: CGFloat = 4
    private static let maxHeight: CGFloat = 28
    private static let visibleBars = 12

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
        .frame(height: Self.maxHeight)
        .opacity(isPaused ? 0.4 : 1.0)
        .mask(
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 12)
                Color.white
            }
        )
    }
}

// MARK: - Content View (iPhone / Watch branching)

private struct RecordingContentView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>
    @Environment(\.activityFamily) var activityFamily

    var body: some View {
        switch activityFamily {
        case .small:
            WatchRecordingView(context: context)
        case .medium:
            iPhoneRecordingView(context: context)
        @unknown default:
            iPhoneRecordingView(context: context)
        }
    }
}

// MARK: - Watch Recording View

private struct WatchRecordingView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    var body: some View {
        let palette = WidgetPalette.current

        HStack(spacing: 8) {
            WatchWaveformWidget(
                levels: context.state.levels,
                isPaused: context.state.isPaused,
                palette: palette
            )

            Spacer(minLength: 4)

            Text(formatTime(context.state.elapsedSeconds))
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white)

            Button(intent: StopDreamRecordingIntent()) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color(red: 1, green: 63 / 255, blue: 66 / 255).opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [palette.gradientStart, palette.gradientEnd],
                startPoint: UnitPoint(x: 0.1, y: 0),
                endPoint: UnitPoint(x: 0.9, y: 1)
            )
            .opacity(isLuminanceReduced ? 0.5 : 1.0)
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - iPhone Recording View

private struct iPhoneRecordingView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>

    var body: some View {
        let palette = WidgetPalette.current

        HStack {
            LiveWaveformWidget(
                levels: context.state.levels,
                levelStartIndex: context.state.levelStartIndex,
                isPaused: context.state.isPaused,
                palette: palette
            )

            Spacer(minLength: 24)

            HStack(spacing: 12) {
                Text(formatTime(context.state.elapsedSeconds))
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Link(destination: URL(string: "reveri://stop-recording")!) {
                    Image("StopIconLock")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .frame(width: 48, height: 48)
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
                .frame(width: 48, height: 48)
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

    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Widget

struct RecordingActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            RecordingContentView(context: context)
        } dynamicIsland: { context in
            dynamicIslandConfig(context: context)
        }
        .supplementalActivityFamilies([.small])
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

    private func timerView(_ state: RecordingActivityAttributes.ContentState) -> some View {
        Text(formatTime(state.elapsedSeconds))
            .monospacedDigit()
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
