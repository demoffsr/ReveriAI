import SwiftUI

struct ProfileView: View {
    var notificationService: NotificationService
    var dreamReminderManager: DreamReminderManager
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @AppStorage("speechRecognitionLocale") private var selectedLocaleId: String = SpeechLocale.defaultLocale.identifier
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 7
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("reminderDays") private var reminderDays = "2,3,4,5,6"

    @State private var reminderDate = Date()

    private var selectedLocale: SpeechLocale {
        SpeechLocale(rawValue: selectedLocaleId) ?? .defaultLocale
    }

    private var selectedDaysSet: Set<Int> {
        Set(reminderDays.split(separator: ",").compactMap { Int($0) })
    }

    private static let weekdaySymbols: [(index: Int, short: String)] = {
        let calendar = Calendar.current
        // Calendar weekday: 1=Sun, 2=Mon, ... 7=Sat
        // Display Mon-Sun order: 2,3,4,5,6,7,1
        let order = [2, 3, 4, 5, 6, 7, 1]
        return order.map { weekday in
            let symbol = calendar.shortWeekdaySymbols[weekday - 1]
            return (index: weekday, short: String(symbol.prefix(2)))
        }
    }()

    var body: some View {
        VStack(spacing: 0) {
            navBar
            scrollContent
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            syncDateFromStorage()
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .reveriGlass(.circle)
            }

            Spacer()

            Text("Profile")
                .font(.headline)

            Spacer()

            // Invisible spacer to balance layout
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Content

    private var scrollContent: some View {
        List {
            // Language section
            Section {
                Menu {
                    ForEach(SpeechLocale.allCases) { locale in
                        Button {
                            selectedLocaleId = locale.identifier
                        } label: {
                            HStack {
                                Text(locale.displayName)
                                if locale == selectedLocale {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Label("Language", systemImage: "globe")
                        Spacer()
                        Text(selectedLocale.displayName)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            } header: {
                Text("Speech Recognition")
            }

            // Reminder section
            Section {
                Toggle(isOn: $reminderEnabled) {
                    Label("Enable Reminder", systemImage: "bell")
                }
                .tint(theme.accent)
                .onChange(of: reminderEnabled) { _, enabled in
                    handleReminderToggle(enabled)
                }

                if reminderEnabled {
                    DatePicker(
                        "Time",
                        selection: $reminderDate,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: reminderDate) { _, newDate in
                        let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                        reminderHour = components.hour ?? 7
                        reminderMinute = components.minute ?? 0
                        reschedule()
                        dreamReminderManager.validateAndAutoStart()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Days")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(Self.weekdaySymbols, id: \.index) { day in
                                let isSelected = selectedDaysSet.contains(day.index)
                                Button {
                                    toggleDay(day.index)
                                } label: {
                                    Text(day.short)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(isSelected ? theme.accent : .secondary)
                                        .frame(width: 36, height: 36)
                                }
                                .buttonStyle(.plain)
                                .background {
                                    if isSelected {
                                        Circle()
                                            .fill(theme.accent.opacity(0.15))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Dream Reminder")
            } footer: {
                if reminderEnabled {
                    Text("At the selected time, a dream reminder will appear on your lock screen. When you wake up, tap Record or Write to capture your dream.")
                }
            }

            if reminderEnabled {
                Section {
                    Button {
                        notificationService.sendTestNotification()
                    } label: {
                        Label("Send Test Notification", systemImage: "bell.badge")
                    }
                } footer: {
                    Text("Sends a test notification in 3 seconds. If the app is open, the Live Activity will start automatically. Minimize the app to test the lock screen flow.")
                }
            }
        }
    }

    // MARK: - Actions

    private func syncDateFromStorage() {
        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute
        if let date = Calendar.current.date(from: components) {
            reminderDate = date
        }
    }

    private func handleReminderToggle(_ enabled: Bool) {
        if enabled {
            Task {
                let granted = await notificationService.requestPermission()
                if granted {
                    reschedule()
                    dreamReminderManager.validateAndAutoStart()
                } else {
                    await MainActor.run { reminderEnabled = false }
                }
            }
        } else {
            notificationService.cancelAllReminders()
            dreamReminderManager.validateAndAutoStart()
        }
    }

    private func toggleDay(_ weekday: Int) {
        var days = selectedDaysSet
        if days.contains(weekday) {
            days.remove(weekday)
        } else {
            days.insert(weekday)
        }
        reminderDays = days.sorted().map(String.init).joined(separator: ",")
        if reminderEnabled {
            reschedule()
            dreamReminderManager.validateAndAutoStart()
        }
    }

    private func reschedule() {
        guard !selectedDaysSet.isEmpty else {
            notificationService.cancelAllReminders()
            return
        }
        notificationService.scheduleReminders(
            hour: reminderHour,
            minute: reminderMinute,
            days: selectedDaysSet
        )
    }
}
