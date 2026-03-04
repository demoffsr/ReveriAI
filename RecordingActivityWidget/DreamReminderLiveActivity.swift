import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Content View (iPhone / Watch branching)

private struct DreamReminderContentView: View {
    @Environment(\.activityFamily) var activityFamily

    var body: some View {
        switch activityFamily {
        case .small:
            WatchDreamReminderView()
        case .medium:
            iPhoneDreamReminderView()
        @unknown default:
            iPhoneDreamReminderView()
        }
    }
}

// MARK: - Watch Dream Reminder View

private struct WatchDreamReminderView: View {
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    var body: some View {
        let palette = WidgetPalette.current

        VStack(spacing: 6) {
            Text(String(localized: "widget.didYouSleepWell", defaultValue: "Did you sleep well?"))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))

            // Record button — Link opens Watch app with deep link
            Link(destination: URL(string: "reveri://record")!) {
                Text(String(localized: "widget.record", defaultValue: "Record"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(palette.accent, in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [palette.gradientStart, palette.gradientEnd],
                startPoint: UnitPoint(x: 0.1, y: 0),
                endPoint: UnitPoint(x: 0.9, y: 1)
            )
            .opacity(isLuminanceReduced ? 0.5 : 1.0)
        }
    }
}

// MARK: - iPhone Dream Reminder View

private struct iPhoneDreamReminderView: View {
    var body: some View {
        let palette = WidgetPalette.current

        VStack(spacing: 16) {
            // Top row: title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "widget.didYouSleepWell", defaultValue: "Did you sleep well?"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Text(String(localized: "widget.tellUsAboutIt", defaultValue: "Tell us about it"))
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Record button
            Button(intent: StartDreamRecordingIntent()) {
                HStack(spacing: 8) {
                    Image("MicrophoneIcon")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    Text(String(localized: "widget.record", defaultValue: "Record"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(palette.accent, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.6),
                                    .white.opacity(0.0),
                                    palette.accentGlow.opacity(0.4),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
                        .padding(1)
                )
            }
            .buttonStyle(.plain)
            .shadow(color: palette.accentGlow.opacity(0.5), radius: 11.2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
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
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .activityBackgroundTint(.clear)
    }
}

// MARK: - Widget

struct DreamReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DreamReminderAttributes.self) { _ in
            DreamReminderContentView()
        } dynamicIsland: { _ in
            dynamicIslandConfig
        }
        .supplementalActivityFamilies([.small])
    }

    // MARK: Dynamic Island

    private var dynamicIslandConfig: DynamicIsland {
        let palette = WidgetPalette.current

        return DynamicIsland {
            DynamicIslandExpandedRegion(.center) {
                Text(String(localized: "widget.didYouSleepWell", defaultValue: "Did you sleep well?"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            DynamicIslandExpandedRegion(.bottom) {
                Button(intent: StartDreamRecordingIntent()) {
                    HStack(spacing: 8) {
                        Image("MicrophoneIcon")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text(String(localized: "widget.record", defaultValue: "Record"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(palette.accent, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.6),
                                        .white.opacity(0.0),
                                        palette.accentGlow.opacity(0.4),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.15), lineWidth: 0.5)
                            .padding(1)
                    )
                }
                .buttonStyle(.plain)
                .shadow(color: palette.accentGlow.opacity(0.5), radius: 11.2)
            }
        } compactLeading: {
            Image("MicrophoneIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(palette.accent)
        } compactTrailing: {
            Text(String(localized: "widget.record", defaultValue: "Record"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(palette.accent)
        } minimal: {
            Image("MicrophoneIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(palette.accent)
        }
    }
}
