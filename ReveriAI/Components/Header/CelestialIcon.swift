import SwiftUI

struct CelestialIcon: View {
    @Environment(\.theme) private var theme
    @State private var isPulsing = false
    @State private var isGlowing = false
    @State private var isTapped = false
    @State private var tapID = 0

    var body: some View {
        ZStack {
            // Radial glow layer — soft ambient light behind everything
            RadialGradient(
                colors: [theme.accent.opacity(isTapped ? 0.35 : (isGlowing ? 0.25 : 0.15)), .clear],
                center: .center,
                startRadius: 10,
                endRadius: isTapped ? 80 : 70
            )
            .frame(width: isTapped ? 160 : 140, height: isTapped ? 160 : 140)

            // Outer glow ring — breathes with slow pulse
            Circle()
                .fill(theme.accent.opacity(isTapped ? 0.18 : (isPulsing ? 0.12 : 0.08)))
                .frame(width: 106, height: 106)
                .scaleEffect(isTapped ? 1.15 : (isPulsing ? 1.06 : 1.0))
            Circle()
                .stroke(theme.accent.opacity(isTapped ? 0.5 : 0.35), lineWidth: 1.2)
                .frame(width: 102, height: 102)
                .scaleEffect(isTapped ? 1.15 : (isPulsing ? 1.06 : 1.0))

            // Inner glow ring — slightly offset timing
            Circle()
                .fill(theme.accent.opacity(isTapped ? 0.25 : (isPulsing ? 0.18 : 0.12)))
                .frame(width: 88, height: 88)
                .scaleEffect(isTapped ? 1.1 : (isPulsing ? 1.04 : 1.0))
            Circle()
                .stroke(theme.accent.opacity(isTapped ? 0.45 : 0.35), lineWidth: 1.0)
                .frame(width: 84, height: 84)
                .scaleEffect(isTapped ? 1.1 : (isPulsing ? 1.04 : 1.0))

            // Main circle with gradient stroke and pulsing glow shadow
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
                .shadow(color: theme.accent.opacity(isTapped ? 0.85 : 0.7), radius: isTapped ? 40 : (isPulsing ? 34 : 28))
                .shadow(color: theme.accent.opacity(isTapped ? 0.45 : 0.3), radius: isTapped ? 70 : (isGlowing ? 60 : 50))


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
        .scaleEffect(isTapped ? 1.06 : 1.0)
        .onTapGesture {
            // Stop repeating animations
            isPulsing = false
            isGlowing = false
            tapID += 1
            let myTapID = tapID
            withAnimation(.spring(duration: 0.3, bounce: 0.35)) {
                isTapped = true
            }
            Task {
                try? await Task.sleep(for: .seconds(0.35))
                withAnimation(.easeOut(duration: 0.5)) {
                    isTapped = false
                }
                // Only the last tap restarts animations
                try? await Task.sleep(for: .seconds(0.6))
                guard tapID == myTapID else { return }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    isGlowing = true
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}
