import SwiftUI

enum WallpaperPreset: String, CaseIterable, Identifiable {
    case defaultTheme = "default"
    case aurora
    case twilight
    case deepOcean
    case nebula
    case moonrise

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultTheme: String(localized: "wallpaper.default", defaultValue: "Default")
        case .aurora: String(localized: "wallpaper.aurora", defaultValue: "Aurora")
        case .twilight: String(localized: "wallpaper.twilight", defaultValue: "Twilight")
        case .deepOcean: String(localized: "wallpaper.deepOcean", defaultValue: "Deep Ocean")
        case .nebula: String(localized: "wallpaper.nebula", defaultValue: "Nebula")
        case .moonrise: String(localized: "wallpaper.moonrise", defaultValue: "Moonrise")
        }
    }

    /// Gradient used for preset thumbnails. Default uses a placeholder gradient for the thumbnail only.
    var gradient: LinearGradient {
        switch self {
        case .defaultTheme:
            // Approximate the BackgroundDaylight asset colors for the thumbnail
            LinearGradient(
                colors: [Color(hex: "C4A5D8"), Color(hex: "E8C4D8"), Color(hex: "F5DDD0")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .aurora:
            LinearGradient(
                colors: [Color(hex: "0A2E1F"), Color(hex: "1B6B4A"), Color(hex: "2CB5A0"), Color(hex: "0A2E1F")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .twilight:
            LinearGradient(
                colors: [Color(hex: "2D1B69"), Color(hex: "8B3A62"), Color(hex: "E87040")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .deepOcean:
            LinearGradient(
                colors: [Color(hex: "0A1628"), Color(hex: "0D2847"), Color(hex: "1A6B7A")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .nebula:
            LinearGradient(
                colors: [Color(hex: "1A0533"), Color(hex: "4A1A6B"), Color(hex: "7B2D8E"), Color(hex: "1A0533")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .moonrise:
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "2D2D4E"), Color(hex: "8E8EA0")],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Whether this preset is the app's built-in default (BackgroundDaylight image + stars).
    var isDefault: Bool {
        self == .defaultTheme
    }
}
