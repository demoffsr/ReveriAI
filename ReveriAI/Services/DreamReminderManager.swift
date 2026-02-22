import ActivityKit
import Foundation
import Observation

@Observable
final class DreamReminderManager {
    var isActive = false

    private var activity: Activity<DreamReminderAttributes>?

    /// Start the dream reminder Live Activity (user taps "Going to sleep")
    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End any existing reminder first
        endSync()

        let state = DreamReminderAttributes.ContentState(status: "sleeping")
        do {
            activity = try Activity.request(
                attributes: DreamReminderAttributes(startTime: .now),
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            isActive = true
        } catch {
            print("DreamReminderManager: start failed — \(error)")
        }
    }

    /// Update to "wake up" state (optional — change UI to emphasize recording)
    func wakeUp() {
        let state = DreamReminderAttributes.ContentState(status: "wakeUp")
        Task { await activity?.update(.init(state: state, staleDate: nil)) }
    }

    /// End the Live Activity (user saved a dream)
    func end() {
        Task {
            let state = DreamReminderAttributes.ContentState(status: "sleeping")
            await activity?.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            activity = nil
            await MainActor.run { isActive = false }
        }
    }

    /// Synchronous end for immediate cleanup
    private func endSync() {
        if let activity {
            Task {
                let state = DreamReminderAttributes.ContentState(status: "sleeping")
                await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            }
        }
        activity = nil
        isActive = false
    }

    /// Refresh the activity to prevent 8-hour auto-termination.
    /// Call from BGTaskScheduler every ~7 hours.
    func refresh() {
        guard activity != nil else { return }
        let state = DreamReminderAttributes.ContentState(status: "sleeping")
        Task { await activity?.update(.init(state: state, staleDate: nil)) }
    }

    /// Reconnect to an existing Live Activity after app restart
    func reconnect() {
        let activities = Activity<DreamReminderAttributes>.activities
        activity = activities.first
        isActive = activity != nil
    }

    /// Validates existing Live Activity or auto-starts one if within sleep window.
    /// Called on appear, foreground transition, and after settings changes in ProfileView.
    func validateAndAutoStart() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: "reminderEnabled")

        if !enabled {
            if isActive { end() }
            return
        }

        let inWindow = isWithinSleepWindow()

        if isActive && !inWindow {
            end()
            return
        }

        if !isActive && inWindow {
            start()
        }
    }

    /// Checks if current time falls within 10 hours after the scheduled reminder time
    /// for today or yesterday (to handle post-midnight wake-ups).
    private func isWithinSleepWindow() -> Bool {
        let defaults = UserDefaults.standard
        let hour = defaults.integer(forKey: "reminderHour")
        let minute = defaults.integer(forKey: "reminderMinute")
        let daysString = defaults.string(forKey: "reminderDays") ?? "2,3,4,5,6"
        let days = Set(daysString.split(separator: ",").compactMap { Int($0) })
        guard !days.isEmpty else { return false }

        let calendar = Calendar.current
        let now = Date()
        let todayWeekday = calendar.component(.weekday, from: now)
        let yesterdayWeekday = todayWeekday == 1 ? 7 : todayWeekday - 1

        var candidates: [Date] = []

        if days.contains(todayWeekday) {
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = hour
            comps.minute = minute
            if let date = calendar.date(from: comps) {
                candidates.append(date)
            }
        }

        if days.contains(yesterdayWeekday),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
            var comps = calendar.dateComponents([.year, .month, .day], from: yesterday)
            comps.hour = hour
            comps.minute = minute
            if let date = calendar.date(from: comps) {
                candidates.append(date)
            }
        }

        let windowDuration: TimeInterval = 10 * 3600
        return candidates.contains { scheduled in
            let elapsed = now.timeIntervalSince(scheduled)
            return elapsed >= 0 && elapsed < windowDuration
        }
    }
}
