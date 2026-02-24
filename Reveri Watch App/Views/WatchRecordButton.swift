import SwiftUI

struct WatchRecordButton: View {
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(accent.opacity(0.1))
                Circle()
                    .stroke(accent.opacity(0.5), lineWidth: 1.0)

                // Middle ring (scaled from SVG: 98.8/120 ≈ 0.823)
                Circle()
                    .fill(accent.opacity(0.2))
                    .padding(16)
                Circle()
                    .stroke(accent.opacity(0.5), lineWidth: 0.8)
                    .padding(16)

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
                    .shadow(color: Color(red: 1.0, green: 0.49, blue: 0.0).opacity(0.9), radius: 35)
                    .shadow(color: Color(red: 1.0, green: 0.49, blue: 0.0).opacity(0.5), radius: 60)

                // Mic icon (custom SVG)
                Image("MicIconBtn")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
            }
            .frame(width: 150, height: 150)
        }
        .buttonStyle(.plain)
    }
}
