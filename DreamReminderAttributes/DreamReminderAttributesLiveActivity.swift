//
//  DreamReminderAttributesLiveActivity.swift
//  DreamReminderAttributes
//
//  Created by Dmitry Demidov on 22.02.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct DreamReminderAttributesAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct DreamReminderAttributesLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DreamReminderAttributesAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension DreamReminderAttributesAttributes {
    fileprivate static var preview: DreamReminderAttributesAttributes {
        DreamReminderAttributesAttributes(name: "World")
    }
}

extension DreamReminderAttributesAttributes.ContentState {
    fileprivate static var smiley: DreamReminderAttributesAttributes.ContentState {
        DreamReminderAttributesAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: DreamReminderAttributesAttributes.ContentState {
         DreamReminderAttributesAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: DreamReminderAttributesAttributes.preview) {
   DreamReminderAttributesLiveActivity()
} contentStates: {
    DreamReminderAttributesAttributes.ContentState.smiley
    DreamReminderAttributesAttributes.ContentState.starEyes
}
