import SwiftUI
import PhotosUI
import StoreKit

struct ProfileView: View {
    var notificationService: NotificationService
    var dreamReminderManager: DreamReminderManager
    var avatarStorage: AvatarStorage
    var headerBackgroundStorage: HeaderBackgroundStorage
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @AppStorage("speechRecognitionLocale") private var selectedLocaleId: String = SpeechLocale.defaultLocale.identifier
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 7
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("reminderDays") private var reminderDays = "2,3,4,5,6"
    @AppStorage("userName") private var userName = ""
    @AppStorage("themeOverride") private var themeOverride = "auto"

    @State private var reminderDate = Date()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isEditingName = false
    @State private var showTimePicker = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false
    @State private var cacheCleared = false
    @State private var showBackgroundPicker = false

    private var selectedLocale: SpeechLocale {
        SpeechLocale(rawValue: selectedLocaleId) ?? .defaultLocale
    }

    private var selectedDaysSet: Set<Int> {
        Set(reminderDays.split(separator: ",").compactMap { Int($0) })
    }

    private static let weekdaySymbols: [(index: Int, short: String)] = {
        let calendar = Calendar.current
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
        .enableSwipeBack()
        .onAppear { syncDateFromStorage() }
        .task { notificationService.checkAuthorizationStatus() }
        .onChange(of: selectedPhoto) { _, item in
            loadPhoto(item)
        }
        .navigationDestination(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .navigationDestination(isPresented: $showTermsOfUse) {
            TermsOfUseView()
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
            Text(String(localized: "profile.title", defaultValue: "Profile"))
                .font(.headline)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                avatarSection
                speechRecognitionCard
                reminderCard
                themeCard
                backgroundCard
                supportCard
                dataCard
                aboutCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let image = avatarStorage.avatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    } else {
                        Circle()
                            .fill(theme.accent.opacity(0.12))
                            .frame(width: 96, height: 96)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(theme.accent.opacity(0.5))
                            }
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }

                    Image(systemName: "camera.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 24, height: 24)
                        .reveriGlass(.circle, interactive: false)
                        .offset(x: -2, y: -2)
                }
            }

            if isEditingName {
                TextField(String(localized: "profile.yourName", defaultValue: "Your name"), text: $userName)
                    .font(.system(size: 17, weight: .medium))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .onSubmit { isEditingName = false }
            } else {
                Button {
                    isEditingName = true
                } label: {
                    Text(userName.isEmpty ? String(localized: "profile.addName", defaultValue: "Add name") : userName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(userName.isEmpty ? .secondary : .primary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Settings Cards

    private var speechRecognitionCard: some View {
        settingsCard(title: String(localized: "profile.speechRecognition", defaultValue: "Speech Recognition")) {
            settingsRow(icon: "globe", iconColor: .blue, title: String(localized: "profile.language", defaultValue: "Language")) {
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
                    HStack(spacing: 4) {
                        Text(selectedLocale.displayName)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var reminderCard: some View {
        settingsCard(title: String(localized: "profile.dreamReminder", defaultValue: "Dream Reminder")) {
            VStack(spacing: 0) {
                // Toggle row
                HStack(spacing: 12) {
                    settingsIcon("bell.fill", color: .orange)
                    Text(String(localized: "profile.enableReminder", defaultValue: "Enable Reminder"))
                        .font(.system(size: 16))
                    Spacer()
                    Toggle("", isOn: $reminderEnabled)
                        .labelsHidden()
                        .tint(theme.accent)
                }
                .frame(height: 52)
                .onChange(of: reminderEnabled) { _, enabled in
                    handleReminderToggle(enabled)
                }

                if reminderEnabled {
                    cardDivider

                    // Time row
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showTimePicker.toggle()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            settingsIcon("clock.fill", color: .purple)
                            Text(String(localized: "profile.time", defaultValue: "Time"))
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(reminderDate, style: .time)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(showTimePicker ? 90 : 0))
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(height: 52)

                    if showTimePicker {
                        DatePicker(
                            "",
                            selection: $reminderDate,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 150)
                        .onChange(of: reminderDate) { _, newDate in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                            reminderHour = components.hour ?? 7
                            reminderMinute = components.minute ?? 0
                            reschedule()
                            dreamReminderManager.validateAndAutoStart()
                        }
                    }

                    cardDivider

                    // Weekday selector
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "profile.days", defaultValue: "Days"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(Self.weekdaySymbols, id: \.index) { day in
                                weekdayButton(day)
                            }
                        }
                    }
                    .frame(height: 72)

                    cardDivider

                    // Test notification
                    Button {
                        notificationService.sendTestNotification()
                    } label: {
                        HStack(spacing: 12) {
                            settingsIcon("bell.badge.fill", color: .red)
                            Text(String(localized: "profile.sendTestNotification", defaultValue: "Send Test Notification"))
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(height: 52)
                }
            }
        }
    }

    private var themeCard: some View {
        settingsCard(title: String(localized: "profile.theme", defaultValue: "Theme")) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    settingsIcon("paintbrush.fill", color: .indigo)
                    Text(String(localized: "profile.appearance", defaultValue: "Appearance"))
                        .font(.system(size: 16))
                    Spacer()
                }

                Picker("", selection: $themeOverride) {
                    Text(String(localized: "profile.auto", defaultValue: "Auto")).tag("auto")
                    Text(String(localized: "profile.day", defaultValue: "Day")).tag("day")
                    Text(String(localized: "profile.night", defaultValue: "Night")).tag("night")
                }
                .pickerStyle(.segmented)
            }
            .frame(minHeight: 52)
        }
    }

    private var backgroundCard: some View {
        settingsCard(title: String(localized: "profile.recordBackground", defaultValue: "Record Background")) {
            VStack(spacing: 0) {
                Button {
                    showBackgroundPicker = true
                } label: {
                    HStack(spacing: 12) {
                        if let bg = headerBackgroundStorage.backgroundImage {
                            Image(uiImage: bg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.accent.opacity(0.12))
                                .frame(width: 40, height: 24)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.accent)
                                }
                        }
                        Text(String(localized: "profile.headerPhoto", defaultValue: "Header Photo"))
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .frame(height: 52)

                if headerBackgroundStorage.backgroundImage != nil {
                    cardDivider

                    Button {
                        headerBackgroundStorage.delete()
                    } label: {
                        HStack(spacing: 12) {
                            settingsIcon("arrow.counterclockwise", color: .red)
                            Text(String(localized: "profile.resetToDefault", defaultValue: "Reset to Default"))
                                .font(.system(size: 16))
                                .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(height: 52)
                }
            }
        }
        .sheet(isPresented: $showBackgroundPicker) {
            HeaderBackgroundPickerSheet(headerBackgroundStorage: headerBackgroundStorage)
        }
    }

    private var supportCard: some View {
        settingsCard(title: String(localized: "profile.support", defaultValue: "Support")) {
            VStack(spacing: 0) {
                // Contact us
                Link(destination: URL(string: "mailto:demidovdmitry07@gmail.com")!) {
                    settingsRowContent(icon: "envelope.fill", iconColor: .green, title: String(localized: "profile.contactUs", defaultValue: "Contact Us"))
                }
                .buttonStyle(.plain)
                .frame(height: 52)

                cardDivider

                // Rate app
                Button {
                    requestReview()
                } label: {
                    settingsRowContent(icon: "star.fill", iconColor: .yellow, title: String(localized: "profile.rateApp", defaultValue: "Rate the App"))
                }
                .buttonStyle(.plain)
                .frame(height: 52)

                cardDivider

                // Privacy Policy
                Button {
                    showPrivacyPolicy = true
                } label: {
                    settingsRowContent(icon: "lock.shield.fill", iconColor: .blue, title: String(localized: "profile.privacyPolicy", defaultValue: "Privacy Policy"))
                }
                .buttonStyle(.plain)
                .frame(height: 52)

                cardDivider

                // Terms of Use
                Button {
                    showTermsOfUse = true
                } label: {
                    settingsRowContent(icon: "doc.text.fill", iconColor: .gray, title: String(localized: "profile.termsOfUse", defaultValue: "Terms of Use"))
                }
                .buttonStyle(.plain)
                .frame(height: 52)
            }
        }
    }

    private var dataCard: some View {
        settingsCard(title: String(localized: "profile.data", defaultValue: "Data")) {
            Button {
                ImageCache.shared.clearAll()
                cacheCleared = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    cacheCleared = false
                }
            } label: {
                HStack(spacing: 12) {
                    settingsIcon("trash.fill", color: .red)
                    Text(String(localized: "profile.clearCache", defaultValue: "Clear Cache"))
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Spacer()
                    if cacheCleared {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(height: 52)
        }
    }

    private var aboutCard: some View {
        settingsCard(title: String(localized: "profile.about", defaultValue: "About")) {
            HStack(spacing: 12) {
                settingsIcon("info.circle.fill", color: .secondary)
                Text(String(localized: "profile.version", defaultValue: "Version"))
                    .font(.system(size: 16))
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
            .frame(height: 52)
        }
    }

    // MARK: - Reusable Components

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 8)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.black.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private func settingsRow<Accessory: View>(icon: String, iconColor: Color, title: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon, color: iconColor)
            Text(title)
                .font(.system(size: 16))
            Spacer()
            accessory()
        }
        .frame(height: 52)
    }

    private func settingsRowContent(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon, color: iconColor)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func settingsIcon(_ name: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(color.opacity(0.12))
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: name)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
            }
    }

    private var cardDivider: some View {
        Divider()
            .background(.black.opacity(0.08))
            .padding(.leading, 40)
    }

    private func weekdayButton(_ day: (index: Int, short: String)) -> some View {
        let isSelected = selectedDaysSet.contains(day.index)
        return Button {
            toggleDay(day.index)
        } label: {
            Text(day.short)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle().fill(theme.accent)
                    } else {
                        Circle().fill(.black.opacity(0.05))
                    }
                }
        }
        .buttonStyle(.plain)
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

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                avatarStorage.save(uiImage: uiImage)
            }
        }
    }
}
