import WidgetKit
import SwiftUI

struct ReveriComplication: Widget {
    let kind = "ReveriComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReveriTimelineProvider()) { entry in
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
        }
        .configurationDisplayName("Reveri")
        .description("Quick dream recording")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

struct ReveriTimelineEntry: TimelineEntry {
    let date: Date
}

struct ReveriTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReveriTimelineEntry {
        ReveriTimelineEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReveriTimelineEntry) -> Void) {
        completion(ReveriTimelineEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReveriTimelineEntry>) -> Void) {
        let entry = ReveriTimelineEntry(date: .now)
        completion(Timeline(entries: [entry], policy: .never))
    }
}
