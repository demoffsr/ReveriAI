import SwiftUI

struct CardWaveformView: View {
    let bars: [CGFloat]
    var playbackProgress: CGFloat = 0 // 0...1
    var frameHeight: CGFloat = 32

    @Environment(\.theme) private var theme

    private static let barWidth: CGFloat = 2

    private var unplayedBarColor: Color {
        theme.isDayTime ? Color(hex: "C3C3C3") : Color(hex: "555555")
    }

    var body: some View {
        Canvas { context, size in
            let count = bars.count
            guard count > 0 else { return }

            let playedColor = theme.accent
            let unplayedColor = unplayedBarColor

            // Calculate how many bars fit, then space evenly
            let minSpacing: CGFloat = 2
            let barSlot = Self.barWidth + minSpacing
            let maxBars = min(count, Int(size.width / barSlot))
            guard maxBars > 0 else { return }

            // Distribute bars evenly across full width
            let totalBarWidth = CGFloat(maxBars) * Self.barWidth
            let spacing = maxBars > 1 ? (size.width - totalBarWidth) / CGFloat(maxBars - 1) : 0
            let slot = Self.barWidth + spacing

            for i in 0..<maxBars {
                let barProgress = CGFloat(i) / CGFloat(max(maxBars - 1, 1))
                let canvasX = CGFloat(i) * slot

                let scale = size.height / 32
                let height = bars[i] * scale
                let y = (size.height - height) / 2
                let rect = CGRect(x: canvasX, y: y, width: Self.barWidth, height: height)
                let color = barProgress <= playbackProgress ? playedColor : unplayedColor
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
            }
        }
        .frame(height: frameHeight)
    }
}
