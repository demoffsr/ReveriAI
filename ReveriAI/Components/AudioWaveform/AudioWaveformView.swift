import SwiftUI

struct AudioWaveformView: View {
    let isAnimating: Bool
    let level: Float // 0...1 normalized audio level
    @Environment(\.theme) private var theme
    @State private var bars: [CGFloat] = []
    /// Reference time when current animation segment started
    @State private var animationStartTime: TimeInterval = 0
    /// Accumulated scroll distance from previous animation segments (pause/resume, tab switch)
    @State private var accumulatedOffset: CGFloat = 0

    private static let barWidth: CGFloat = 2
    private static let barSpacing: CGFloat = 3.6
    private static let barSlot: CGFloat = barWidth + barSpacing
    private static let minHeight: CGFloat = 4
    private static let maxHeight: CGFloat = 100
    private static let scrollSpeed: CGFloat = barSlot * 20 // 20 bars/sec

    var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { timeline in
            // Compute scroll offset from timeline — no separate Task needed
            let elapsed = isAnimating
                ? timeline.date.timeIntervalSinceReferenceDate - animationStartTime
                : 0
            let scrollOffset = accumulatedOffset + Self.scrollSpeed * CGFloat(max(0, elapsed))

            Canvas { context, size in
                let totalBars = bars.count
                guard totalBars > 0 else { return }

                let accentColor = theme.accent
                let rightEdge = size.width
                let subBarOffset = scrollOffset.truncatingRemainder(dividingBy: Self.barSlot)

                for i in stride(from: totalBars - 1, through: 0, by: -1) {
                    let reverseIndex = totalBars - 1 - i
                    let x = rightEdge - CGFloat(reverseIndex) * Self.barSlot - subBarOffset
                    if x + Self.barWidth < 0 { break }
                    if x > size.width { continue }

                    let height = bars[i]
                    let y = (size.height - height) / 2
                    let rect = CGRect(x: x, y: y, width: Self.barWidth, height: height)
                    let path = Path(roundedRect: rect, cornerRadius: 1)
                    context.fill(path, with: .color(accentColor))
                }
            }
        }
        .frame(height: Self.maxHeight + 20)
        .onChange(of: isAnimating) { _, animating in
            if animating {
                animationStartTime = Date.now.timeIntervalSinceReferenceDate
            } else {
                // Save progress so next segment continues smoothly
                let elapsed = Date.now.timeIntervalSinceReferenceDate - animationStartTime
                accumulatedOffset += Self.scrollSpeed * CGFloat(max(0, elapsed))
            }
        }
        .onChange(of: level) { _, newLevel in
            guard isAnimating else { return }
            let clamped = CGFloat(max(0, min(1, newLevel)))
            let height = Self.minHeight + clamped * (Self.maxHeight - Self.minHeight)
            bars.append(height)
            if bars.count > 500 {
                bars.removeFirst(bars.count - 500)
            }
        }
        .onAppear {
            if isAnimating {
                animationStartTime = Date.now.timeIntervalSinceReferenceDate
            }
        }
        .onDisappear {
            if isAnimating {
                let elapsed = Date.now.timeIntervalSinceReferenceDate - animationStartTime
                accumulatedOffset += Self.scrollSpeed * CGFloat(max(0, elapsed))
            }
        }
    }
}
