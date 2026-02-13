import SwiftUI

struct AudioWaveformView: View {
    let isAnimating: Bool
    let level: Float // 0...1 normalized audio level
    @Environment(\.theme) private var theme
    /// Reference-type buffer — mutations don't trigger SwiftUI state diffs
    @State private var buffer = WaveformBuffer()
    @State private var animationStartTime: TimeInterval?
    @State private var accumulatedOffset: CGFloat = 0

    private static let barWidth: CGFloat = 2
    private static let barSpacing: CGFloat = 3.6
    private static let barSlot: CGFloat = barWidth + barSpacing
    private static let minHeight: CGFloat = 4
    private static let maxHeight: CGFloat = 100
    private static let barsPerSecond: Double = 20
    private static let scrollSpeed: CGFloat = barSlot * CGFloat(barsPerSecond)

    var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let elapsed = isAnimating ? now - (animationStartTime ?? now) : 0
            let scrollOffset = accumulatedOffset + Self.scrollSpeed * CGFloat(max(0, elapsed))

            // Update buffer in TimelineView closure (not inside Canvas)
            // so `level` is read here where Observation tracking works.
            let _ = buffer.update(
                scrollOffset: scrollOffset,
                barSlot: Self.barSlot,
                currentLevel: level,
                minHeight: Self.minHeight,
                maxHeight: Self.maxHeight
            )

            Canvas { context, size in
                let bars = buffer.bars
                let count = bars.count
                guard count > 0 else { return }

                let accentColor = theme.accent

                // Grows LEFT → RIGHT. Once full, scroll so newest stays at right edge.
                let windowStart = max(0, scrollOffset - size.width)

                for i in 0..<count {
                    let waveformX = CGFloat(i) * Self.barSlot
                    let canvasX = waveformX - windowStart
                    if canvasX > size.width { break }
                    if canvasX + Self.barWidth < 0 { continue }

                    let height = bars[i]
                    let y = (size.height - height) / 2
                    let rect = CGRect(x: canvasX, y: y, width: Self.barWidth, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(accentColor))
                }
            }
        }
        .frame(height: Self.maxHeight + 20)
        .onChange(of: isAnimating) { _, animating in
            if animating {
                animationStartTime = Date.now.timeIntervalSinceReferenceDate
            } else if let start = animationStartTime {
                let elapsed = Date.now.timeIntervalSinceReferenceDate - start
                accumulatedOffset += Self.scrollSpeed * CGFloat(max(0, elapsed))
                animationStartTime = nil
            }
        }
        .onAppear {
            if isAnimating && animationStartTime == nil {
                animationStartTime = Date.now.timeIntervalSinceReferenceDate
            }
        }
        .onDisappear {
            if isAnimating, let start = animationStartTime {
                let elapsed = Date.now.timeIntervalSinceReferenceDate - start
                accumulatedOffset += Self.scrollSpeed * CGFloat(max(0, elapsed))
                animationStartTime = nil
            }
        }
    }
}

// MARK: - WaveformBuffer

/// Reference-type buffer for waveform bars.
/// Mutations here do NOT trigger SwiftUI state diffs — only TimelineView drives redraws.
private final class WaveformBuffer {
    var bars: [CGFloat] = []
    private var lastBarIndex: Int = -1
    private var smoothedLevel: Float = 0

    @discardableResult
    func update(
        scrollOffset: CGFloat,
        barSlot: CGFloat,
        currentLevel: Float,
        minHeight: CGFloat,
        maxHeight: CGFloat
    ) -> Bool {
        // Smooth the incoming level for visual continuity
        let target = max(0, min(1, currentLevel))
        if target > smoothedLevel {
            // Fast attack — responsive to loud sounds
            smoothedLevel = smoothedLevel * 0.3 + target * 0.7
        } else {
            // Moderate decay — bars settle naturally
            smoothedLevel = smoothedLevel * 0.8 + target * 0.2
        }

        // Add bars synced to scroll position (1 bar per barSlot of scroll distance)
        let currentBarIndex = Int(scrollOffset / barSlot)
        var added = false

        if currentBarIndex > lastBarIndex {
            let barsToAdd = min(currentBarIndex - lastBarIndex, 5)
            let clamped = CGFloat(smoothedLevel)
            let height = minHeight + clamped * (maxHeight - minHeight)
            for _ in 0..<barsToAdd {
                bars.append(height)
            }
            lastBarIndex = currentBarIndex
            added = true

            // Trim old bars that scrolled off-screen
            if bars.count > 500 {
                bars.removeFirst(bars.count - 500)
            }
        }
        return added
    }
}
