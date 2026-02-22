import ActivityKit
import SwiftUI
import WidgetKit

struct DreamReminderLiveActivity: Widget {
    private static let accentOrange = Color(red: 1.0, green: 170.0 / 255.0, blue: 0.0) // #FFAA00

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DreamReminderAttributes.self) { context in
            // Lock screen banner
            VStack(spacing: 16) {
                // Top row: icon + text
                HStack(spacing: 12) {
                    // App icon
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 37, height: 37)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Title + subtitle
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Record your Dream")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Don't forget to record dream")
                            .font(.system(size: 14.5))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()
                }

                // Bottom row: Record + Write buttons
                HStack(spacing: 8) {
                    Link(destination: URL(string: "reveri://record")!) {
                        Text("Record")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Self.accentOrange, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Link(destination: URL(string: "reveri://write")!) {
                        Text("Write")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color(red: 14.0 / 255.0, green: 14.0 / 255.0, blue: 26.0 / 255.0)) // #0E0E1A

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(Self.accentOrange)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Record your Dream")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: URL(string: "reveri://record")!) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(Self.accentOrange)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        Link(destination: URL(string: "reveri://record")!) {
                            Text("Record")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Self.accentOrange, in: RoundedRectangle(cornerRadius: 12))
                        }

                        Link(destination: URL(string: "reveri://write")!) {
                            Text("Write")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(Self.accentOrange)
            } compactTrailing: {
                Text("Dream")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Self.accentOrange)
            } minimal: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(Self.accentOrange)
            }
        }
    }
}
