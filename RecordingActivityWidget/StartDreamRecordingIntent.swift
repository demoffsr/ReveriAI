import AppIntents
import ActivityKit

struct StartDreamRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Recording"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("startDreamRecordingFromLA"),
                object: nil
            )
        }
        return .result()
    }
}
