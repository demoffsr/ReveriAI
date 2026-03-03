import SwiftUI

struct LoaderView: View {
    private let isDayTime: Bool
    private let baseColor: Color
    private let gradientColor: Color

    @State private var gradientOpacity: Double = 0
    @State private var isPulsing = false

    init() {
        let hour = Calendar.current.component(.hour, from: .now)
        isDayTime = hour >= 5 && hour < 21
        baseColor = Color(hex: isDayTime ? "FFAA00" : "0E0E1A")
        // Day: #EB5200 (orange-red), Night: #0073AD (teal blue)
        gradientColor = isDayTime
            ? Color(red: 0.92, green: 0.32, blue: 0)
            : Color(red: 0, green: 0.45, blue: 0.68)
    }

    var body: some View {
        ZStack {
            // Layer 1: Solid background — matches system launch screen exactly
            baseColor
                .ignoresSafeArea()

            // Layer 2: Bottom gradient overlay — fades in after appear
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(height: 522)
                    .background(
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: gradientColor.opacity(0), location: 0.00),
                                Gradient.Stop(color: gradientColor, location: 1.00),
                            ],
                            startPoint: UnitPoint(x: 0.5, y: 0),
                            endPoint: UnitPoint(x: 0.5, y: 1)
                        )
                    )
            }
            .ignoresSafeArea()
            .opacity(gradientOpacity)

            // Layer 3: Logo with breathing pulse + glow
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .shadow(
                    color: (isDayTime ? Color.white : gradientColor).opacity(isPulsing ? 0.5 : 0.25),
                    radius: isPulsing ? 30 : 15
                )
                .scaleEffect(isPulsing ? 1.08 : 1.0)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: isPulsing
                )
        }
        .onAppear {
            // Delay slightly so first frame matches system launch screen
            withAnimation(.easeOut(duration: 0.8)) {
                gradientOpacity = 1
            }
            // Start breathing pulse
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
