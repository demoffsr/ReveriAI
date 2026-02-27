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
                emotionCircle(emotion, isSelected: isSelected, isDimmed: hasSelection && !isSelected)
                Text(emotion.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.black.opacity(0.7))
            }
            .frame(width: 62)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3), value: isSelected)
    }

    private func emotionCircle(_ emotion: DreamEmotion, isSelected: Bool, isDimmed: Bool) -> some View {
        ZStack {
            Image(emotion.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: circleSize - 12, height: circleSize - 12)
                .frame(width: circleSize, height: circleSize)
                .reveriGlass(.circle, interactive: false)

            if isSelected {
                Circle()
                    .fill(emotion.color.opacity(0.25))
                    .frame(width: circleSize, height: circleSize)
            }

            Circle()
                .fill(.black.opacity(isDimmed ? 0.55 : 0))
                .frame(width: circleSize, height: circleSize)
                .allowsHitTesting(false)
        }
        .frame(width: circleSize, height: circleSize)
    }
}
