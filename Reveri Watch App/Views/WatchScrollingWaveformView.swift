import SwiftUI

// MARK: - WatchWaveformState

/// Reference-type container for waveform state. NOT @Observable — mutations happen
/// inside Canvas/TimelineView and must not trigger parent view re-evaluation.
final class WatchWaveformState {
    var bars: [CGFloat] = []
    var smoothedLevel: Float = 0
    var animationStartTime: TimeInterval?
    var accumulatedOffset: CGFloat = 0

    private var lastBarIndex: Int = -1

    init() {
        bars.reserveCapacity(1024)
    }

    func reset() {
        bars.removeAll(keepingCapacity: true)
        lastBarIndex = -1
        smoothedLevel = 0
        animationStartTime = nil
        accumulatedOffset = 0
    }

    @discardableResult
    func update(
        scrollOffset: CGFloat,
        barSlot: CGFloat,
        currentLevel: Float,
        minHeight: CGFloat,
        maxHeight: CGFloat
    ) -> Bool {
        let target = max(0, min(1, currentLevel))
        if target > smoothedLevel {
            smoothedLevel = smoothedLevel * 0.3 + target * 0.7
        } else {
            smoothedLevel = smoothedLevel * 0.8 + target * 0.2
        }

        let currentBarIndex = Int(scrollOffset / barSlot)
        guard currentBarIndex > lastBarIndex else { return false }

        let barsToAdd = min(currentBarIndex - lastBarIndex, 5)
        let height = minHeight + CGFloat(smoothedLevel) * (maxHeight - minHeight)
        for _ in 0..<barsToAdd {
            bars.append(height)
        }
        lastBarIndex = currentBarIndex
        return true
    }
}

// MARK: - WatchScrollingWaveformView

struct WatchScrollingWaveformView: View {
    let isAnimating: Bool
    let level: Float
    let waveformState: WatchWaveformState
    var accentColor: Color = .white

    private static let barWidth: CGFloat = 3.37
    private static let barSpacing: CGFloat = 3.05
    private static let barSlot: CGFloat = barWidth + barSpacing
    private static let minHeight: CGFloat = 5
    private static let maxHeight: CGFloat = 52
    private static let barsPerSecond: Double = 20
    private static let scrollSpeed: CGFloat = barSlot * CGFloat(barsPerSecond)

    private func scrollOffset(now: TimeInterval) -> CGFloat {
        let elapsed = isAnimating ? now - (waveformState.animationStartTime ?? now) : 0
        return waveformState.accumulatedOffset + Self.scrollSpeed * CGFloat(max(0, elapsed))
    }

    var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let offset = scrollOffset(now: now)

            let _ = isAnimating ? waveformState.update(
                scrollOffset: offset,
                barSlot: Self.barSlot,
                currentLevel: level,
                minHeight: Self.minHeight,
                maxHeight: Self.maxHeight
            ) : false

            Canvas { context, size in
                let bars = waveformState.bars
                let count = bars.count
                guard count > 0 else { return }

                let windowStart = max(0, offset - size.width)

                for i in 0..<count {
                    let waveformX = CGFloat(i) * Self.barSlot
                    let canvasX = waveformX - windowStart
                    if canvasX > size.width { break }
                    if canvasX + Self.barWidth < 0 { continue }

                    let height = bars[i]
                    let y = (size.height - height) / 2
                    let rect = CGRect(x: canvasX, y: y, width: Self.barWidth, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: Self.barWidth / 2), with: .color(accentColor))
                }
            }
        }
        .frame(height: Self.maxHeight)
        .onChange(of: isAnimating) { _, animating in
            if animating {
                waveformState.animationStartTime = Date.now.timeIntervalSinceReferenceDate
            } else if let start = waveformState.animationStartTime {
                let elapsed = Date.now.timeIntervalSinceReferenceDate - start
                waveformState.accumulatedOffset += Self.scrollSpeed * CGFloat(max(0, elapsed))
                waveformState.animationStartTime = nil
            }
        }
        .onAppear {
            if isAnimating && waveformState.animationStartTime == nil {
                waveformState.animationStartTime = Date.now.timeIntervalSinceReferenceDate
            }
        }
        .onDisappear {
            if isAnimating, let start = waveformState.animationStartTime {
                let elapsed = Date.now.timeIntervalSinceReferenceDate - start
                waveformState.accumulatedOffset += Self.scrollSpeed * CGFloat(max(0, elapsed))
                waveformState.animationStartTime = nil
            }
        }
    }
}
