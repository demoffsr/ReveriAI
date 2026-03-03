import Foundation
import UserNotifications
import Observation

@Observable
final class NotificationService {
    var isAuthorized = false

    static let categoryId = "DREAM_REMINDER"
    static let recordActionId = "RECORD_ACTION"
    static let writeActionId = "WRITE_ACTION"

    private static let notificationDelegate = NotificationDelegate()

    init() {
        // isAuthorized читается только в ProfileView — проверяем там через .task
    }

    /// Call once from App.init — before any notification can arrive
    static func setupDelegate() {
        let center = UNUserNotificationCenter.current()
        center.delegate = notificationDelegate

        let recordAction = UNNotificationAction(
            identifier: recordActionId,
            title: "Record",
            options: [.foreground]
        )
        let writeAction = UNNotificationAction(
            identifier: writeActionId,
            title: "Write",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [recordAction, writeAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted }
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Scheduling

    func scheduleReminders(hour: Int, minute: Int, days: Set<Int>) {
        let center = UNUserNotificationCenter.current()
        // Remove existing reminders first
        let ids = (1...7).map { "dream_reminder_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        for weekday in days {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.weekday = weekday  // 1=Sunday, 2=Monday, ...7=Saturday

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let content = Self.makeReminderContent()

            let request = UNNotificationRequest(
                identifier: "dream_reminder_\(weekday)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func cancelAllReminders() {
        let ids = (1...7).map { "dream_reminder_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func removeDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    /// Send a test notification in 3 seconds (for verifying setup)
    func sendTestNotification() {
        let content = Self.makeReminderContent()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "dream_reminder_test",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    private static func makeReminderContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Time to Sleep"
        content.body = "Tap to activate dream reminder on your lock screen"
        content.sound = .default
        content.categoryIdentifier = categoryId
        return content
    }
}

// MARK: - Notification Delegate (standalone NSObject — no @Observable isolation)

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let category = response.notification.request.content.categoryIdentifier

        switch response.actionIdentifier {
        case NotificationService.recordActionId:
            NotificationCenter.default.post(name: .dreamReminderRecord, object: nil)
        case NotificationService.writeActionId:
            NotificationCenter.default.post(name: .dreamReminderWrite, object: nil)
        case UNNotificationDefaultActionIdentifier:
            if category == NotificationService.categoryId {
                // Tap on notification body → start Live Activity
                NotificationCenter.default.post(name: .dreamReminderStartActivity, object: nil)
            }
        default:
            break
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let category = notification.request.content.categoryIdentifier
        if category == NotificationService.categoryId {
            // App in foreground at reminder time → auto-start Live Activity, suppress banner
            NotificationCenter.default.post(name: .dreamReminderStartActivity, object: nil)
            completionHandler([])
        } else {
            completionHandler([.banner, .sound])
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let dreamReminderRecord = Notification.Name("dreamReminderRecord")
    static let dreamReminderWrite = Notification.Name("dreamReminderWrite")
    static let dreamReminderStartActivity = Notification.Name("dreamReminderStartActivity")
}
