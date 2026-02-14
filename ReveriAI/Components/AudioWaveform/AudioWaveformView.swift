import SwiftUI

struct AudioWaveformView: View {
    let isAnimating: Bool
    let level: Float // 0...1 normalized audio level
    var isPlayingBack: Bool = false
    var playbackProgress: CGFloat = 0 // 0...1 current playback position
    var playbackDuration: TimeInterval = 0

    @Environment(\.theme) private var theme
    /// Reference-type buffer — mutations don't trigger SwiftUI state diffs
    @State private var buffer = WaveformBuffer()
    @State private var animationStartTime: TimeInterval?
    @State private var accumulatedOffset: CGFloat = 0
    /// Total scroll distance captured when recording ends — used as 100% for playback
    @State private var totalRecordedOffset: CGFloat = 0
    /// Playback animation state
    @State private var playbackAnimStartTime: TimeInterval?
    @State private var playbackAnimStartOffset: CGFloat = 0

    private static let barWidth: CGFloat = 2
    private static let barSpacing: CGFloat = 3.6
    private static let barSlot: CGFloat = barWidth + barSpacing
    private static let minHeight: CGFloat = 4
    private static let maxHeight: CGFloat = 100
    private static let barsPerSecond: Double = 20
    private static let scrollSpeed: CGFloat = barSlot * CGFloat(barsPerSecond)

    private var isTimelinePaused: Bool {
        !isAnimating && playbackAnimStartTime == nil
    }

    /// Compute scroll offset based on current mode (playback, review, or recording).
    private func scrollOffset(now: TimeInterval) -> CGFloat {
        if let pStart = playbackAnimStartTime, playbackDuration > 0, totalRecordedOffset > 0 {
            // Playback: smooth 60fps scroll driven by timeline
            let elapsed = now - pStart
            let speed = totalRecordedOffset / CGFloat(playbackDuration)
            return min(playbackAnimStartOffset + speed * CGFloat(elapsed), totalRecordedOffset)
        } else if totalRecordedOffset > 0 && !isAnimating {
            // Review mode (paused or before play): static position from progress
            return totalRecordedOffset * playbackProgress
        } else {
            // Recording or idle
            let elapsed = isAnimating ? now - (animationStartTime ?? now) : 0
            return accumulatedOffset + Self.scrollSpeed * CGFloat(max(0, elapsed))
        }
    }

    var body: some View {
        TimelineView(.animation(paused: isTimelinePaused)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let offset = scrollOffset(now: now)

            // Only generate new bars during recording (ternary avoids ViewBuilder ambiguity)
            let _ = isAnimating ? buffer.update(
                scrollOffset: offset,
                barSlot: Self.barSlot,
                currentLevel: level,
                minHeight: Self.minHeight,
                maxHeight: Self.maxHeight
            ) : false

            Canvas { context, size in
                let bars = buffer.bars
                let count = bars.count
                guard count > 0 else { return }

                let accentColor = theme.accent

                // During playback/review, keep playhead near left edge so scrolling is visible immediately.
                // During recording, scroll only once bars fill the screen width.
                let isInPlayback = !isAnimating && totalRecordedOffset > 0
                let visibleWidth = isInPlayback ? size.width * 0.2 : size.width
                let windowStart = max(0, offset - visibleWidth)

                for i in 0..<count {
                    let waveformX = CGFloat(i + buffer.trimOffset) * Self.barSlot
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
                totalRecordedOffset = accumulatedOffset
            }
        }
        .onChange(of: isPlayingBack) { _, playing in
            if playing {
                // Start/resume: sync with external playback position
                playbackAnimStartOffset = totalRecordedOffset * playbackProgress
                playbackAnimStartTime = Date.now.timeIntervalSinceReferenceDate
            } else if let start = playbackAnimStartTime {
                // Pause: capture current animated position
                let elapsed = Date.now.timeIntervalSinceReferenceDate - start
                let speed = playbackDuration > 0 ? totalRecordedOffset / CGFloat(playbackDuration) : 0
                playbackAnimStartOffset = min(
                    playbackAnimStartOffset + speed * CGFloat(elapsed),
                    totalRecordedOffset
                )
                playbackAnimStartTime = nil
            }
        }
        .onChange(of: playbackProgress) { oldVal, newVal in
            guard playbackAnimStartTime != nil, totalRecordedOffset > 0 else { return }
            let delta = abs(newVal - oldVal)
            if delta > 0.02 {
                playbackAnimStartOffset = totalRecordedOffset * newVal
                playbackAnimStartTime = Date.now.timeIntervalSinceReferenceDate
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
    var trimOffset: Int = 0
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
        }
        return added
    }
}
