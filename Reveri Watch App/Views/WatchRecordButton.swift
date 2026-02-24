import SwiftUI

struct WatchRecordButton: View {
    let accent: Color
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(accent.opacity(isPulsing ? 0.15 : 0.1))
                    .overlay(Circle().stroke(accent.opacity(0.5), lineWidth: 1.0))
                    .scaleEffect(isPulsing ? 1.06 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isPulsing)

                // Middle ring (scaled from SVG: 98.8/120 ≈ 0.823)
                Circle()
                    .fill(accent.opacity(isPulsing ? 0.25 : 0.2))
                    .overlay(Circle().stroke(accent.opacity(0.5), lineWidth: 0.8))
                    .padding(16)
                    .scaleEffect(isPulsing ? 1.04 : 1.0)
                    .animation(.easeInOut(duration: 2.3).repeatForever(autoreverses: true), value: isPulsing)

                // Main circle with gradient fill + gradient stroke + glow shadow
                Circle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 1.0, green: 0.57, blue: 0.0), location: 0.29),
                                .init(color: accent, location: 1.0)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        Circle().stroke(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.73, blue: 0.19), Color(red: 1.0, green: 0.73, blue: 0.19).opacity(0)],
                                startPoint: .top, endPoint: .bottom
                            ), lineWidth: 1.5
                        )
                    )
                    .padding(32)
                    .shadow(color: Color(red: 1.0, green: 0.49, blue: 0.0).opacity(0.9), radius: isPulsing ? 42 : 35)
                    .shadow(color: Color(red: 1.0, green: 0.49, blue: 0.0).opacity(0.5), radius: isPulsing ? 70 : 60)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isPulsing)

                // Mic icon (custom SVG)
                Image("MicIconBtn")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
            }
            .frame(width: 150, height: 150)
        }
        .buttonStyle(.plain)
        .onAppear { isPulsing = true }
    }
}
