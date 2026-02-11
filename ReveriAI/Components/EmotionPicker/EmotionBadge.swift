import SwiftUI

struct EmotionBadge: View {
    let emotion: DreamEmotion
    var isSelected: Bool = false
    var size: CGFloat = 44

    var body: some View {
        VStack(spacing: 4) {
            Text(emotion.emoji)
                .font(.system(size: size * 0.6))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(emotion.color.opacity(isSelected ? 0.25 : 0.1))
                )
                .overlay(
                    Circle()
                        .stroke(emotion.color, lineWidth: isSelected ? 2 : 0)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)

            Text(emotion.displayName)
                .font(.caption2)
                .foregroundStyle(isSelected ? emotion.color : .secondary)
        }
        .animation(.spring(duration: 0.3), value: isSelected)
    }
}
