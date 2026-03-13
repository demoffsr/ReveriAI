import SwiftUI

struct EmotionCarousel: View {
    @Binding var selectedEmotions: Set<DreamEmotion>

    private let allEmotions: [DreamEmotion] = [.confused, .joyful, .inLove, .calm, .anxious, .scared, .angry]
    private let circleSize: CGFloat = 50

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allEmotions) { emotion in
                    emotionItem(emotion)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func emotionItem(_ emotion: DreamEmotion) -> some View {
        let isSelected = selectedEmotions.contains(emotion)
        let hasSelection = !selectedEmotions.isEmpty

        return Button {
            HapticService.selection()
            if isSelected {
                selectedEmotions.remove(emotion)
            } else {
                selectedEmotions.insert(emotion)
            }
        } label: {
            VStack(spacing: 6) {
                emotionCircle(emotion, isSelected: isSelected)
                Text(emotion.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary.opacity(isSelected ? 0.7 : 0.3))
            }
            .frame(width: 62)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3), value: isSelected)
    }

    private func emotionCircle(_ emotion: DreamEmotion, isSelected: Bool) -> some View {
        Image(emotion.iconName)
            .resizable()
            .scaledToFit()
            .frame(width: circleSize - 12, height: circleSize - 12)
            .frame(width: circleSize, height: circleSize)
            .overlay(
                Circle().stroke(
                    isSelected ? emotion.color : .white.opacity(0.7),
                    lineWidth: isSelected ? 1.5 : 1
                )
            )
            .background {
                if isSelected {
                    Circle().fill(emotion.color.opacity(0.25))
                }
            }
            .reveriGlass(.circle, interactive: false)
            .shadow(color: .black.opacity(0.05), radius: 10.9, x: 0, y: 2)
    }
}
