import SwiftUI

struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let isExpanded: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? accentColor : .secondary)

                if isExpanded {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(.horizontal, isExpanded ? 16 : 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? accentColor.opacity(0.12) : .clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}
