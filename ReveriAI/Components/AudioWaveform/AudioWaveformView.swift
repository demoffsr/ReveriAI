import SwiftUI

struct AudioWaveformView: View {
    let isAnimating: Bool
    let level: Float // 0...1 normalized audio level
    @Environment(\.theme) private var theme
    @State private var bars: [CGFloat] = []
    // Monotonic offset — drives smooth scroll in Canvas without state churn
    @State private var scrollOffset: CGFloat = 0
    @State private var displayLink: Task<Void, Never>?

    private static let barWidth: CGFloat = 2
    private static let barSpacing: CGFloat = 3.6
    private static let barSlot: CGFloat = barWidth + barSpacing
    private static let minHeight: CGFloat = 4
    private static let maxHeight: CGFloat = 100
    // Speed: pixels per second the waveform scrolls left
    private static let scrollSpeed: CGFloat = barSlot * 20 // 20 bars/sec

    var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { timeline in
            let _ = timeline.date // force redraw each frame
            Canvas { context, size in
                let accentColor = theme.accent
                let totalBars = bars.count
                guard totalBars > 0 else { return }

                // rightEdge = where the newest bar sits
                let rightEdge = size.width
                let subBarOffset = scrollOffset.truncatingRemainder(dividingBy: Self.barSlot)

                for i in stride(from: totalBars - 1, through: 0, by: -1) {
                    let reverseIndex = totalBars - 1 - i
                    let x = rightEdge - CGFloat(reverseIndex) * Self.barSlot - subBarOffset
                    if x + Self.barWidth < 0 { break } // off-screen left
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
        .onChange(of: isAnimating) { _, on in
            if on { startScroll() }
            else { stopScroll() }
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
            if isAnimating { startScroll() }
        }
        .onDisappear { stopScroll() }
    }

    // MARK: - Smooth scroll via CADisplayLink-style loop

    private func startScroll() {
        displayLink?.cancel()
        var lastTime = CACurrentMediaTime()
        displayLink = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(8)) // ~120 checks/sec, capped by display
                guard !Task.isCancelled else { break }
                let now = CACurrentMediaTime()
                let dt = now - lastTime
                lastTime = now
                scrollOffset += Self.scrollSpeed * CGFloat(dt)
            }
        }
    }

    private func stopScroll() {
        displayLink?.cancel()
        displayLink = nil
    }
}
