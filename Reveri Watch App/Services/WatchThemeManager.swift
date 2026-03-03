import SwiftUI

@Observable
final class WatchThemeManager {
    var isDayTime: Bool

    init() {
        let hour = Calendar.current.component(.hour, from: .now)
        isDayTime = hour >= 5 && hour < 21
    }

    var accent: Color {
        isDayTime ? .dayAccent : .nightAccent
    }

    var backgroundGradient: LinearGradient {
        isDayTime ? .dayHeaderGradient : .nightHeaderGradient
    }

    func refresh() {
        let hour = Calendar.current.component(.hour, from: .now)
        isDayTime = hour >= 5 && hour < 21
    }
}
