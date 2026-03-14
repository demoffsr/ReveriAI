import SwiftUI
import PhotosUI
import StoreKit

struct ProfileView: View {
    var notificationService: NotificationService
    var dreamReminderManager: DreamReminderManager
    var avatarStorage: AvatarStorage
    var headerBackgroundStorage: HeaderBackgroundStorage
    @Binding var isInDetailDreamTab: Bool
    @Binding var detailDreamHasImage: Bool
    @Binding var detailDreamIsGenerating: Bool
    @Binding var detailDreamGenerateTrigger: Bool
    var detailState: DetailDreamState
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
    @State private var showBackgroundPicker = false
    @State private var showAvatarDialog = false
    @State private var showAvatarPhotoPicker = false
    @State private var dayPreset: DayPreset = .weekdays
    @State private var showArchive = false
    @State private var showHeaderPhotoDialog = false

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
        .background((theme.isDayTime ? Color(.systemGroupedBackground) : .darkBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .onAppear { syncDateFromStorage() }
        .task { notificationService.checkAuthorizationStatus() }
        .onChange(of: selectedPhoto) { _, item in
            loadPhoto(item)
        }
        .navigationDestination(isPresented: $showArchive) {
            ArchiveView(
                isInDetailDreamTab: $isInDetailDreamTab,
                detailDreamHasImage: $detailDreamHasImage,
                detailDreamIsGenerating: $detailDreamIsGenerating,
                detailDreamGenerateTrigger: $detailDreamGenerateTrigger,
                detailState: detailState
            )
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
            VStack(spacing: 20) {
                avatarSection
                headerPhotoCard
                mainSettingsCard
                archiveCard
                supportCardSection
                dataAndAboutCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: 12) {
            Button {
                showAvatarDialog = true
            } label: {
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
            .confirmationDialog(
                String(localized: "profile.avatarOptions", defaultValue: "Profile Photo"),
                isPresented: $showAvatarDialog,
                titleVisibility: .visible
            ) {
                Button(String(localized: "profile.chooseFromLibrary", defaultValue: "Choose from Library")) {
                    showAvatarPhotoPicker = true
                }
                if avatarStorage.avatarImage != nil {
                    Button(String(localized: "profile.removePhoto", defaultValue: "Remove Photo"), role: .destructive) {
                        avatarStorage.delete()
                    }
                }
            }
            .photosPicker(isPresented: $showAvatarPhotoPicker, selection: $selectedPhoto, matching: .images)

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
                    if userName.isEmpty {
                        Text(String(localized: "profile.addName", defaultValue: "Add your name"))
                            .font(.system(size: 17))
                            .italic()
                            .foregroundStyle(.secondary)
                    } else {
                        Text(userName)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Header Photo Card

    private var headerPhotoCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Group {
                    if let bg = headerBackgroundStorage.backgroundImage {
                        Image(uiImage: bg)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image("BackgroundDaylight")
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipped()
            }

            Divider()

            Button {
                showHeaderPhotoDialog = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge("ProfileDay", color: .purple)
                    Text(String(localized: "profile.headerPhoto", defaultValue: "Header Photo"))
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(String(localized: "profile.change", defaultValue: "Change"))
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 48)
                .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                String(localized: "profile.headerPhotoOptions", defaultValue: "Header Photo"),
                isPresented: $showHeaderPhotoDialog,
                titleVisibility: .visible
            ) {
                Button(String(localized: "profile.chooseFromGallery", defaultValue: "Choose from Gallery")) {
                    showBackgroundPicker = true
                }
                if headerBackgroundStorage.backgroundImage != nil {
                    Button(String(localized: "profile.resetToDefault", defaultValue: "Reset to Default"), role: .destructive) {
                        headerBackgroundStorage.delete()
                    }
                }
            }
        }
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardStroke, lineWidth: 1))
        .sheet(isPresented: $showBackgroundPicker) {
            HeaderBackgroundPickerSheet(headerBackgroundStorage: headerBackgroundStorage)
        }
    }

    // MARK: - Main Settings Card

    private var themeDisplayName: String {
        switch themeOverride {
        case "day": String(localized: "profile.day", defaultValue: "Day")
        case "night": String(localized: "profile.night", defaultValue: "Night")
        default: String(localized: "profile.auto", defaultValue: "Auto")
        }
    }

    private var mainSettingsCard: some View {
        card {
            // Theme row
            Menu {
                Button {
                    themeOverride = "auto"
                    AnalyticsService.track(.themeChanged, metadata: ["theme": "auto"])
                } label: {
                    if themeOverride == "auto" { Image(systemName: "checkmark") }
                    Text(String(localized: "profile.auto", defaultValue: "Auto"))
                }
                Button {
                    themeOverride = "day"
                    AnalyticsService.track(.themeChanged, metadata: ["theme": "day"])
                } label: {
                    if themeOverride == "day" { Image(systemName: "checkmark") }
                    Text(String(localized: "profile.day", defaultValue: "Day"))
                }
                Button {
                    themeOverride = "night"
                    AnalyticsService.track(.themeChanged, metadata: ["theme": "night"])
                } label: {
                    if themeOverride == "night" { Image(systemName: "checkmark") }
                    Text(String(localized: "profile.night", defaultValue: "Night"))
                }
            } label: {
                HStack(spacing: 12) {
                    iconBadge("ProfileNight", color: .indigo)
                    Text(String(localized: "profile.theme", defaultValue: "Theme"))
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(themeDisplayName)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 48)
            }
            .tint(theme.accent)

            rowDivider

            // Language row
            Menu {
                ForEach(SpeechLocale.allCases) { locale in
                    Button {
                        AnalyticsService.track(.languageChanged, metadata: ["locale": locale.identifier])
                        selectedLocaleId = locale.identifier
                    } label: {
                        if locale == selectedLocale { Image(systemName: "checkmark") }
                        Text(locale.shortDisplayName)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    iconBadge(systemName: "globe", color: .blue)
                    Text(String(localized: "profile.language", defaultValue: "Language"))
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(selectedLocale.shortDisplayName)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 48)
            }
            .tint(theme.accent)

            rowDivider

            // Reminder toggle row
            HStack(spacing: 12) {
                iconBadge("ProfileReminder", color: .orange)
                Text(String(localized: "profile.dreamReminder", defaultValue: "Dream Reminder"))
                    .font(.system(size: 16))
                Spacer()
                Toggle("", isOn: $reminderEnabled)
                    .labelsHidden()
                    .tint(theme.accent)
            }
            .frame(height: 48)
            .onChange(of: reminderEnabled) { _, enabled in
                handleReminderToggle(enabled)
            }

            // Expandable reminder details
            if reminderEnabled {
                rowDivider

                // Time row
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showTimePicker.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        iconBadge("ProfileDay", color: .purple)
                        Text(String(localized: "profile.timeToBed", defaultValue: "Time to Bed"))
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(reminderDate, style: .time)
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(showTimePicker ? 90 : 0))
                    }
                    .frame(height: 48)
                }
                .buttonStyle(.plain)

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
                        AnalyticsService.track(.reminderTimeChanged, metadata: [
                            "hour": reminderHour,
                            "minute": reminderMinute
                        ])
                        reschedule()
                        dreamReminderManager.validateAndAutoStart()
                    }
                }

                rowDivider

                // Day presets — segmented control
                Picker("", selection: $dayPreset) {
                    ForEach(DayPreset.allCases, id: \.rawValue) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 8)
                .onChange(of: dayPreset) { _, newPreset in
                    applyDayPreset(newPreset)
                }

                // Weekday circles — only for custom preset
                if dayPreset == .custom {
                    rowDivider

                    HStack(spacing: 6) {
                        ForEach(Self.weekdaySymbols, id: \.index) { day in
                            weekdayButton(day)
                        }
                    }
                    .frame(height: 52)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                }
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.15), value: reminderEnabled)
        .animation(.spring(duration: 0.3, bounce: 0.15), value: dayPreset)
        .onAppear { dayPreset = computeDayPreset() }
    }

    // MARK: - Archive Card

    private var archiveCard: some View {
        card {
            Button {
                showArchive = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge("BoxIcon", color: .primary)
                    Text(String(localized: "profile.archive", defaultValue: "Archive"))
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 48)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Support Card

    private var supportCardSection: some View {
        card {
            Link(destination: URL(string: "mailto:demidovdmitry07@gmail.com")!) {
                HStack(spacing: 12) {
                    iconBadge("ProfileContact", color: .green)
                    Text(String(localized: "profile.contactUs", defaultValue: "Contact Us"))
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 48)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                AnalyticsService.track(.contactUsTapped)
            })

            rowDivider

            Button {
                AnalyticsService.track(.rateAppTapped)
                requestReview()
            } label: {
                HStack(spacing: 12) {
                    iconBadge("ProfileRate", color: .yellow)
                    Text(String(localized: "profile.rateApp", defaultValue: "Rate the App"))
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 48)
            }
            .buttonStyle(.plain)

            rowDivider

            Button {
                showPrivacyPolicy = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge("ProfilePrivacy", color: .blue)
                    Text(String(localized: "profile.privacyPolicy", defaultValue: "Privacy Policy"))
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 48)
            }
            .buttonStyle(.plain)

            rowDivider

            Button {
                showTermsOfUse = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge("ProfileTerms", color: .gray)
                    Text(String(localized: "profile.termsOfUse", defaultValue: "Terms of Use"))
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 48)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Data & About Card

    private var dataAndAboutCard: some View {
        card {
            HStack(spacing: 12) {
                iconBadge("ProfileVersion", color: .secondary)
                Text(String(localized: "profile.version", defaultValue: "Version"))
                    .font(.system(size: 16))
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 48)
        }
    }

    // MARK: - Helpers

    private func iconBadge(_ asset: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color.opacity(0.15))
            .frame(width: 32, height: 32)
            .overlay {
                Image(asset)
                    .resizable().scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(color)
            }
    }

    private func iconBadge(systemName: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color.opacity(0.15))
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 14)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardStroke, lineWidth: 1))
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 38)
    }

    private func weekdayButton(_ day: (index: Int, short: String)) -> some View {
        let isSelected = selectedDaysSet.contains(day.index)
        return Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                toggleDay(day.index)
            }
        } label: {
            Text(day.short)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .primary.opacity(0.4))
                .frame(width: 38, height: 38)
                .background {
                    if isSelected {
                        Circle().fill(theme.accent)
                    }
                }
                .reveriGlass(.circle, interactive: false)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day Preset

    private enum DayPreset: String, CaseIterable {
        case everyDay = "every_day"
        case weekdays = "weekdays"
        case custom = "custom"

        var displayName: String {
            switch self {
            case .everyDay: String(localized: "profile.everyDay", defaultValue: "Every day")
            case .weekdays: String(localized: "profile.weekdays", defaultValue: "Weekdays")
            case .custom: String(localized: "profile.custom", defaultValue: "Custom")
            }
        }
    }

    private func computeDayPreset() -> DayPreset {
        let days = selectedDaysSet
        if days == Set(1...7) { return .everyDay }
        if days == Set(2...6) { return .weekdays }
        return .custom
    }

    private func applyDayPreset(_ preset: DayPreset) {
        switch preset {
        case .everyDay:
            reminderDays = (1...7).map(String.init).joined(separator: ",")
        case .weekdays:
            reminderDays = (2...6).map(String.init).joined(separator: ",")
        case .custom:
            break
        }
        if reminderEnabled {
            reschedule()
            dreamReminderManager.validateAndAutoStart()
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
        AnalyticsService.track(.reminderToggled, metadata: ["enabled": enabled])
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
