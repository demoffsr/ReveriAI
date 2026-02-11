import SwiftUI

struct TabBarItem: View {
    let activeIcon: String
    let inactiveIcon: String
    let label: String
    let isSelected: Bool
    let isExpanded: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(isSelected ? activeIcon : inactiveIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)

                if isExpanded {
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(accentColor)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(.horizontal, isExpanded ? 16 : 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? accentColor.opacity(0.15) : .clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}
