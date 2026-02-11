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
    let compressionRatio: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Gradient background
            theme.headerGradient
                .ignoresSafeArea(edges: .top)

            // Stars
            StarsCanvas()
                .opacity(Double(compressionRatio))

            // Content
            HStack(alignment: .top) {
                // Title
                VStack(alignment: .leading, spacing: 0) {
                    Text("What did")
                        .font(.system(size: 36 * compressionRatio, weight: .bold))
                        .foregroundStyle(.white)
                    Text("you dream")
                        .font(.system(size: 36 * compressionRatio, weight: .bold))
                        .foregroundStyle(.white)
                    Text("about...?")
                        .font(.system(size: 36 * compressionRatio, weight: .bold))
                        .foregroundStyle(theme.accent)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.top, 60 * compressionRatio)
                .padding(.leading, 20)

                Spacer(minLength: 0)

                // Celestial icon
                CelestialIcon()
                    .padding(.top, 50 * compressionRatio)
                    .padding(.trailing, 12)
                    .scaleEffect(compressionRatio)
            }
        }
    }
}
