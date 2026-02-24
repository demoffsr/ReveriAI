import SwiftUI

struct WatchWaveformView: View {
    let bars: [Float]
    var accentColor: Color = .white

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(accentColor.opacity(0.5 + Double(value) * 0.5))
                    .frame(width: 3, height: CGFloat(value) * 30 + 3)
            }
        }
        .frame(height: 36)
    }
}
