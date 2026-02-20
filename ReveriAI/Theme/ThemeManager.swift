import SwiftUI

@Observable
final class ThemeManager {
    var isDayTime: Bool

    private var timer: Timer?
    private var backgroundObserver: Any?
    private var foregroundObserver: Any?

    init() {
        self.isDayTime = Self.calculateIsDayTime()
        startMonitoring()
        observeAppLifecycle()
    }

    deinit {
        timer?.invalidate()
        if let obs = backgroundObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = foregroundObserver { NotificationCenter.default.removeObserver(obs) }
    }

    private static func calculateIsDayTime() -> Bool {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour >= 5 && hour < 21
    }

    private func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isDayTime = Self.calculateIsDayTime()
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
            self?.isDayTime = Self.calculateIsDayTime()
            self?.startMonitoring()
        }
    }

    func refreshTheme() {
        isDayTime = Self.calculateIsDayTime()
    }

    // MARK: - Accent

    var accent: Color {
        isDayTime ? .dayAccent : .nightAccent
    }

    // MARK: - Screen

    var screenBackground: Color { isDayTime ? .cloudFront : Color(hex: "1C1C1E") }
    var cardBackground: Color { isDayTime ? .white : Color(hex: "2C2C2E") }
}
