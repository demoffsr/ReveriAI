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
            HStack(spacing: isExpanded ? 6 : 0) {
                Image(isSelected ? activeIcon : inactiveIcon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
                    .foregroundStyle(isSelected ? accentColor : Color.black.opacity(0.3))

                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(accentColor)
                    .fixedSize()
                    .frame(width: isExpanded ? nil : 0, alignment: .leading)
                    .opacity(isExpanded ? 1 : 0)
                    .clipped()
            }
            .padding(.horizontal, isExpanded ? 16 : 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? accentColor.opacity(0.15) : .clear)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .contentShape(Capsule())
    }
}
