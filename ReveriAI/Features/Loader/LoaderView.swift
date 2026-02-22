import SwiftUI

struct LoaderView: View {
    // Figma: #FFAA00 base, #FF5900 radial glow
    private let baseColor = Color(hex: "FFAA00")
    private let glowColor = Color(hex: "FF5900")

    var body: some View {
        ZStack {
            // Layer 1: Solid amber background (matches LaunchBackground color set)
            baseColor
                .ignoresSafeArea()

            // Layer 2: Radial glow from center
            RadialGradient(
                colors: [glowColor.opacity(0.7), glowColor.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: 350
            )
            .ignoresSafeArea()

            // Layer 3: White logo with shadow
            // No fade-in — must match system launch screen for seamless handoff
            Image("LoaderLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 141, height: 141)  // Match SVG intrinsic size (viewBox 141×141)
                .shadow(color: .black.opacity(0.2), radius: 8, x: -2, y: 2)
        }
    }
}
