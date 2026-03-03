import SwiftUI

// MARK: - Time of Day

enum WidgetTimeOfDay {
    case day, night

    static var current: WidgetTimeOfDay {
        let hour = Calendar.current.component(.hour, from: .now)
        return (hour >= 5 && hour < 21) ? .day : .night
    }
}

// MARK: - Palette

struct WidgetPalette {
    let gradientStart: Color
    let gradientEnd: Color
    let accent: Color
    let accentGlow: Color
    let isNight: Bool

    static let night = WidgetPalette(
        gradientStart: Color(red: 14 / 255, green: 14 / 255, blue: 26 / 255),
        gradientEnd: Color(red: 27 / 255, green: 80 / 255, blue: 123 / 255),
        accent: Color(red: 0, green: 170 / 255, blue: 1),
        accentGlow: Color(red: 18 / 255, green: 173 / 255, blue: 254 / 255),
        isNight: true
    )

    static let day = WidgetPalette(
        gradientStart: Color(red: 26 / 255, green: 18 / 255, blue: 14 / 255),
        gradientEnd: Color(red: 220 / 255, green: 117 / 255, blue: 0),
        accent: Color(red: 1, green: 174 / 255, blue: 0),
        accentGlow: Color(red: 254 / 255, green: 180 / 255, blue: 18 / 255),
        isNight: false
    )

    static var current: WidgetPalette {
        WidgetTimeOfDay.current == .day ? .day : .night
    }
}
