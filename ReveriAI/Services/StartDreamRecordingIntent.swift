import AppIntents
import ActivityKit

struct StartDreamRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            // End the DreamReminder LA — Recording LA will replace it
            for activity in Activity<DreamReminderAttributes>.activities {
                Task {
                    await activity.end(
                        .init(state: .init(status: "sleeping"), staleDate: nil),
                        dismissalPolicy: .immediate
                    )
                }
            }

            // Notify RootView to start recording (which creates Recording LA)
            NotificationCenter.default.post(
                name: Notification.Name("startDreamRecordingFromLA"),
                object: nil
            )
        }
        return .result()
    }
}
