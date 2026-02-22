import ActivityKit
import SwiftUI
import WidgetKit

struct DreamReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DreamReminderAttributes.self) { context in
            // Lock screen banner
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Record your Dream")
                        .font(.headline)
                    Text("Don't let the details fade")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Link(destination: URL(string: "reveri://record")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 14))
                        Text("Record")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.orange, in: .capsule)
                }

                Link(destination: URL(string: "reveri://write")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                        Text("Write")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.blue, in: .capsule)
                }
            }
            .padding()

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Record your Dream")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: URL(string: "reveri://record")!) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.orange)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        Link(destination: URL(string: "reveri://record")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "mic.fill")
                                Text("Record")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.orange, in: .capsule)
                        }

                        Link(destination: URL(string: "reveri://write")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                Text("Write")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.blue, in: .capsule)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text("Dream")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.orange)
            } minimal: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
}
