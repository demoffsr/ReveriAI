import SwiftUI

extension Color {
    static let dayAccent = Color(hex: "FFAA00")
    static let nightAccent = Color(hex: "00AAFF")

    static let headerDarkBrown = Color(hex: "1A0E00")
    static let headerMidBrown = Color(hex: "2D1B0E")
    static let headerLightBrown = Color(hex: "3D2B1E")

    static let headerDarkNavy = Color(hex: "0A0A1A")
    static let headerMidNavy = Color(hex: "0D1B2A")
    static let headerLightNavy = Color(hex: "1A2744")

    static let cloudBackDay = Color(hex: "CDB390")
    static let cloudMidDay = Color(hex: "E0C7A6")
    static let cloudBackNight = Color(hex: "A1AECE")
    static let cloudMidNight = Color(hex: "B6BDCF")
    static let cloudFront = Color(hex: "F2F2F2")
}

extension LinearGradient {
    static let dayHeaderGradient = LinearGradient(
        colors: [.headerDarkBrown, .headerMidBrown, .headerLightBrown],
        startPoint: .top,
        endPoint: .bottom
    )

    static let nightHeaderGradient = LinearGradient(
        colors: [.headerDarkNavy, .headerMidNavy, .headerLightNavy],
        startPoint: .top,
        endPoint: .bottom
    )
}
