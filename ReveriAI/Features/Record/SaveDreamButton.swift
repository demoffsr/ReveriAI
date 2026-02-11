import SwiftUI

struct SaveDreamButton: View {
    @Environment(\.theme) private var theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Save Dream")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.accent.opacity(0.15))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
