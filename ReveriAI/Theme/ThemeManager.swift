import SwiftUI

@Observable
final class ThemeManager {
    var isDayTime: Bool

    private var timer: Timer?

    init() {
        self.isDayTime = Self.calculateIsDayTime()
        startMonitoring()
    }

    private static func calculateIsDayTime() -> Bool {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour >= 5 && hour < 21
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isDayTime = Self.calculateIsDayTime()
            }
        }
    }

    func refreshTheme() {
        isDayTime = Self.calculateIsDayTime()
    }

    // MARK: - Accent

    var accent: Color {
        isDayTime ? .dayAccent : .nightAccent
    }

    // MARK: - Header

    var headerGradient: LinearGradient {
        isDayTime ? .dayHeaderGradient : .nightHeaderGradient
    }

    // MARK: - Clouds

    var cloudBack: Color { isDayTime ? .cloudBackDay : .cloudBackNight }
    var cloudMid: Color { isDayTime ? .cloudMidDay : .cloudMidNight }
    var cloudFront: Color { .cloudFront }

    // MARK: - Celestial

    var celestialIconName: String { isDayTime ? "sun.max.fill" : "moon.fill" }
}
