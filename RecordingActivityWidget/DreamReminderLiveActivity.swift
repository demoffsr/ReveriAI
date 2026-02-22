import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Celestial Decoration

private struct CelestialDecoration: View {
    let palette: WidgetPalette

    var body: some View {
        Image(palette.isNight ? "MoonLock" : "SunLock")
            .resizable()
            .scaledToFit()
    }
}

// MARK: - Widget

struct DreamReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DreamReminderAttributes.self) { _ in
            lockScreenBanner
        } dynamicIsland: { _ in
            dynamicIslandConfig
        }
    }

    // MARK: Lock Screen Banner

    private var lockScreenBanner: some View {
        let palette = WidgetPalette.current

        // Content drives the size; gradient, noise, celestial are layered behind via background/overlay
        return VStack(spacing: 16) {
            // Top row: title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text("Did you sleep well?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Tell us about it")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Bottom row: Record + Write buttons
            HStack(spacing: 8) {
                Button(intent: StartDreamRecordingIntent()) {
                    Text("Record")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(palette.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .shadow(color: palette.accentGlow.opacity(0.5), radius: 11.2)

                Link(destination: URL(string: "reveri://write")!) {
                    Image("WriteIconLock")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.35), in: Circle())
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .white.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background {
            ZStack {
                // Gradient
                LinearGradient(
                    colors: [palette.gradientStart, palette.gradientEnd],
                    startPoint: UnitPoint(x: 0.1, y: 0),
                    endPoint: UnitPoint(x: 0.9, y: 1)
                )

                // Noise texture
                Image("NoiseTexture")
                    .resizable(resizingMode: .tile)
                    .opacity(0.5)
                    .blendMode(.hardLight)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Celestial decoration — doesn't affect layout
            // SVG viewBox 101×102, visual center at (76,24) — with topTrailing alignment
            // this naturally places the celestial at the correct position, no offset needed.
            CelestialDecoration(palette: palette)
                .frame(width: 101, height: 102)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .activityBackgroundTint(.clear)
    }

    // MARK: Dynamic Island

    private var dynamicIslandConfig: DynamicIsland {
        let palette = WidgetPalette.current

        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                Image(systemName: palette.isNight ? "moon.fill" : "sun.max.fill")
                    .foregroundStyle(palette.accent)
            }
            DynamicIslandExpandedRegion(.center) {
                Text("Record your dream")
                    .font(.headline)
            }
            DynamicIslandExpandedRegion(.trailing) {
                Button(intent: StartDreamRecordingIntent()) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(palette.accent)
                }
                .buttonStyle(.plain)
            }
            DynamicIslandExpandedRegion(.bottom) {
                HStack(spacing: 8) {
                    Button(intent: StartDreamRecordingIntent()) {
                        Text("Record")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(palette.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .shadow(color: palette.accentGlow.opacity(0.4), radius: 8)

                    Link(destination: URL(string: "reveri://write")!) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.15), in: Circle())
                    }
                }
            }
        } compactLeading: {
            Image(systemName: palette.isNight ? "moon.fill" : "sun.max.fill")
                .foregroundStyle(palette.accent)
        } compactTrailing: {
            Text("Dream")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(palette.accent)
        } minimal: {
            Image(systemName: palette.isNight ? "moon.fill" : "sun.max.fill")
                .foregroundStyle(palette.accent)
        }
    }
}
