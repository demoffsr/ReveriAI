import SwiftUI

struct CelestialIcon: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            // Outer glow ring (replaces blur+drawingGroup — no Metal shader needed)
            Circle()
                .fill(theme.accent.opacity(0.08))
                .frame(width: 106, height: 106)
            Circle()
                .stroke(theme.accent.opacity(0.35), lineWidth: 1.2)
                .frame(width: 102, height: 102)

            // Inner glow ring
            Circle()
                .fill(theme.accent.opacity(0.12))
                .frame(width: 88, height: 88)
            Circle()
                .stroke(theme.accent.opacity(0.35), lineWidth: 1.0)
                .frame(width: 84, height: 84)

            // Main circle with gradient stroke and warm drop shadow
            Circle()
                .fill(theme.accent)
                .frame(width: 65, height: 65)
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [theme.accent, theme.accent.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        ), lineWidth: 2.3
                    )
                )
                .shadow(color: theme.accent.opacity(0.7), radius: 28)

            // Icon (theme-aware: custom sun SVG / SF Symbol moon)
            Group {
                if theme.isDayTime {
                    Image("SunIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                } else {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 30, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
        }
        .frame(width: 120, height: 120)
    }
}
