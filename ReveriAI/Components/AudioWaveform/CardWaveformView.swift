import SwiftUI

struct CardWaveformView: View {
    let bars: [CGFloat]
    var playbackProgress: CGFloat = 0 // 0...1

    @Environment(\.theme) private var theme

    private static let barWidth: CGFloat = 2
    private static let frameHeight: CGFloat = 32

    var body: some View {
        Canvas { context, size in
            let count = bars.count
            guard count > 0 else { return }

            let playedColor = theme.accent
            let unplayedColor = Color(hex: "C3C3C3")

            // Fixed 2pt spacing, bars fill available width
            let barSlot = Self.barWidth + 2

            for i in 0..<count {
                let barProgress = CGFloat(i) / CGFloat(max(count - 1, 1))
                let canvasX = CGFloat(i) * barSlot

                let height = bars[i]
                let y = (size.height - height) / 2
                let rect = CGRect(x: canvasX, y: y, width: Self.barWidth, height: height)
                let color = barProgress <= playbackProgress ? playedColor : unplayedColor
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
            }
        }
        .frame(height: Self.frameHeight)
    }
}
