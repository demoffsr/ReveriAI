import SwiftUI

struct EmotionPickerGrid: View {
    @Binding var selectedEmotions: Set<DreamEmotion>

    private let gridOrder: [[DreamEmotion]] = [
        [.confused, .joyful, .inLove, .calm],
        [.anxious, .scared, .angry]
    ]

    private let circleSize: CGFloat = 44

    @State private var visibleItems: Set<DreamEmotion> = []

    var body: some View {
        VStack(spacing: 12) {
            ForEach(gridOrder.indices, id: \.self) { rowIndex in
                HStack(spacing: 0) {
                    ForEach(Array(gridOrder[rowIndex].enumerated()), id: \.element) { colIndex, emotion in
                        let flatIndex = rowIndex * 4 + colIndex
                        let isVisible = visibleItems.contains(emotion)
                        emotionItem(emotion)
                            .frame(maxWidth: .infinity)
                            .offset(y: isVisible ? 0 : -30)
                            .scaleEffect(isVisible ? 1 : 0.5)
                            .opacity(isVisible ? 1 : 0)
                            .animation(
                                .spring(duration: 0.5, bounce: 0.35)
                                    .delay(Double(flatIndex) * 0.06),
                                value: isVisible
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            visibleItems = Set(gridOrder.flatMap { $0 })
        }
        .onDisappear {
            visibleItems = []
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
            .frame(width: 56)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3), value: isSelected)
    }

    private func emotionCircle(_ emotion: DreamEmotion, isSelected: Bool, isDimmed: Bool) -> some View {
        ZStack {
            // Glass circle with emotion image inside
            Image(emotion.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: circleSize - 12, height: circleSize - 12)
                .frame(width: circleSize, height: circleSize)
                .reveriGlass(.circle, interactive: false)

            // Selection tint
            if isSelected {
                Circle()
                    .fill(emotion.color.opacity(0.25))
                    .frame(width: circleSize, height: circleSize)
            }

            // Dimming overlay
            Circle()
                .fill(.black.opacity(isDimmed ? 0.55 : 0))
                .frame(width: circleSize, height: circleSize)
                .allowsHitTesting(false)
        }
        .frame(width: circleSize, height: circleSize)
    }
}
