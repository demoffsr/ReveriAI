import SwiftUI

struct EmotionTagBadge: View {
    let emotion: DreamEmotion
    var iconSize: CGFloat = 16
    var fontSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 4) {
            Image(emotion.iconName)
                .resizable()
                .frame(width: iconSize, height: iconSize)
            Text(emotion.displayName)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(emotion.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(emotion.color.opacity(0.15))
        .clipShape(Capsule())
    }
}
