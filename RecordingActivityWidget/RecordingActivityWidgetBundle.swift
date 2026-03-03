import SwiftUI
import WidgetKit

@main
struct RecordingActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecordingActivityWidgetLiveActivity()
        DreamReminderLiveActivity()
    }
}
