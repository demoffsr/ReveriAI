import SwiftUI

struct SaveDreamButton: View {
    @Environment(\.theme) private var theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image("CheckmarkIconAction")
                    .renderingMode(.original)
                Text("Save Dream")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(theme.accent.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.7), lineWidth: 1)
            )
            .glassEffect(.clear.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }
}
