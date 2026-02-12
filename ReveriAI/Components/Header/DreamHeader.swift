import SwiftUI

struct StarsCanvas: View {
    var body: some View {
        Canvas { context, size in
            for i in 0..<50 {
                let seed = Double(i)
                let x = ((seed * 127.1).truncatingRemainder(dividingBy: 1.0).magnitude) * size.width
                let y = ((seed * 311.7).truncatingRemainder(dividingBy: 1.0).magnitude) * size.height
                let radius = 0.5 + ((seed * 269.5).truncatingRemainder(dividingBy: 1.0).magnitude) * 1.5
                let opacity = 0.3 + ((seed * 183.3).truncatingRemainder(dividingBy: 1.0).magnitude) * 0.7

                context.opacity = opacity
                context.fill(
                    Circle().path(in: CGRect(x: x, y: y, width: radius, height: radius)),
                    with: .color(.white)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

struct DreamHeader: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            // Background image (future: user-selected photo)
            Image("BackgroundDaylight")
                .resizable()
                .aspectRatio(contentMode: .fill)

            // Darkening gradient overlay for text readability
            LinearGradient(
                stops: [
                    Gradient.Stop(color: .black, location: 0.00),
                    Gradient.Stop(color: .black.opacity(0), location: 1.00),
                ],
                startPoint: UnitPoint(x: 0.5, y: -0.36),
                endPoint: UnitPoint(x: 0.5, y: 1)
            )

            // Stars
            StarsCanvas()
        }
    }
}
