import AppIntents
import ActivityKit

struct StopDreamRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Recording"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("stopDreamRecording"),
                object: nil
            )
        }
        return .result()
    }
}
