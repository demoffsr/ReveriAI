import SwiftUI

@Observable
final class ThemeManager {
    var isDayTime: Bool

    private var timer: Timer?
    private var backgroundObserver: Any?
    private var foregroundObserver: Any?
    private var themeOverrideObserver: Any?

    init() {
        self.isDayTime = Self.calculateIsDayTime()
        applyOverride()
        startMonitoring()
        observeAppLifecycle()
        observeThemeOverride()
    }

    deinit {
        timer?.invalidate()
        if let obs = backgroundObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = foregroundObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = themeOverrideObserver { NotificationCenter.default.removeObserver(obs) }
    }

    private static func calculateIsDayTime() -> Bool {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour >= 5 && hour < 21
    }

    private func updateIfNeeded() {
        applyOverride()
    }

    private func applyOverride() {
        let override = UserDefaults.standard.string(forKey: "themeOverride") ?? "auto"
        switch override {
        case "day":
            isDayTime = true
        case "night":
            isDayTime = false
        default:
            let newValue = Self.calculateIsDayTime()
            isDayTime = newValue
        }
    }

    private func observeThemeOverride() {
        themeOverrideObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.applyOverride()
        }
    }

    private func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateIfNeeded()
            }
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func observeAppLifecycle() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.stopMonitoring()
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.updateIfNeeded()
            self?.startMonitoring()
        }
    }

    // MARK: - Accent

    var accent: Color {
        isDayTime ? .dayAccent : .nightAccent
    }

    // MARK: - Header

    var headerGradient: LinearGradient {
        isDayTime ? .dayHeaderGradient : .nightHeaderGradient
    }

    var headerBottom: Color { isDayTime ? .headerLightBrown : .headerLightNavy }

    // MARK: - Clouds

    var cloudBack: Color { isDayTime ? .cloudBackDay : .cloudBackNightDark }
    var cloudMid: Color { isDayTime ? .cloudMidDay : .cloudMidNightDark }
    var cloudFront: Color { isDayTime ? .cloudFront : .cloudFrontNight }

    // MARK: - Text

    var textPrimary: Color { isDayTime ? .black : .white }
    var textSecondary: Color { isDayTime ? .black.opacity(0.5) : .white.opacity(0.5) }
    var textTertiary: Color { isDayTime ? .black.opacity(0.3) : .white.opacity(0.3) }

    // MARK: - Cards

    var cardBackground: Color { isDayTime ? .white : .darkCard }
    var cardStroke: Color { isDayTime ? .black.opacity(0.1) : .white.opacity(0.1) }
    var dividerColor: Color { isDayTime ? .black.opacity(0.15) : .white.opacity(0.15) }

    // MARK: - Celestial

    var celestialIconName: String { isDayTime ? "sun.max.fill" : "moon.fill" }
}
