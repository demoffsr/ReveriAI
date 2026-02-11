import SwiftUI

struct CelestialIcon: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(theme.accent.opacity(0.12 - Double(i) * 0.03), lineWidth: 1)
                    .frame(
                        width: 56 + CGFloat(i) * 18,
                        height: 56 + CGFloat(i) * 18
                    )
            }

            // Soft glow
            Circle()
                .fill(theme.accent.opacity(0.3))
                .frame(width: 48, height: 48)
                .blur(radius: 16)

            // Icon circle background
            Circle()
                .fill(theme.accent)
                .frame(width: 40, height: 40)

            // SF Symbol
            Image(systemName: theme.celestialIconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 90, height: 90)
    }
}
