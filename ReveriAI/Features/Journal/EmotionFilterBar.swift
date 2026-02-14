import SwiftUI

struct EmotionFilterBar: View {
    @Binding var selectedEmotion: DreamEmotion?
    @Environment(\.theme) private var theme
    @State private var isExpanded = false
    /// Persistent dynamic order — most recently selected bubbles to front
    @State private var emotionOrder: [DreamEmotion] = DreamEmotion.allCases

    private let circleSize: CGFloat = 42
    private let collapsedSpacing: CGFloat = -14
    private let expandedSpacing: CGFloat = 4

    /// Fixed collapsed width so layout doesn't shift
    private var collapsedWidth: CGFloat {
        let count = CGFloat(DreamEmotion.allCases.count)
        return circleSize + (count - 1) * (circleSize + collapsedSpacing)
    }

    var body: some View {
        Group {
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: expandedSpacing) {
                        ForEach(emotionOrder) { emotion in
                            emotionCircle(emotion)
                                .id(emotion)
                                .onTapGesture {
                                    selectEmotion(emotion)
                                }
                        }
                    }
                }
                .transition(.blurReplace)
            } else {
                HStack(spacing: collapsedSpacing) {
                    ForEach(Array(emotionOrder.enumerated()), id: \.element.id) { index, emotion in
                        emotionCircle(emotion)
                            .id(emotion)
                            .zIndex(Double(emotionOrder.count - index))
                    }
                }
                .onTapGesture {
                    withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                        isExpanded = true
                    }
                }
                .transition(.blurReplace)
            }
        }
        .frame(width: collapsedWidth, alignment: .trailing)
        .mask(
            HStack(spacing: 0) {
                Rectangle()
                Rectangle().frame(width: 40).padding(.trailing, -40)
            }
        )
    }

    private func selectEmotion(_ emotion: DreamEmotion) {
        withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
            if selectedEmotion == emotion {
                selectedEmotion = nil
            } else {
                selectedEmotion = emotion
                emotionOrder.removeAll { $0 == emotion }
                emotionOrder.insert(emotion, at: 0)
            }
            isExpanded = false
        }
    }

    private func emotionCircle(_ emotion: DreamEmotion) -> some View {
        let isSelected = selectedEmotion == emotion
        let isDimmed = selectedEmotion != nil && !isSelected

        return ZStack {
            // Solid dark base — normalizes glass appearance regardless of background
            Circle()
                .fill(Color(white: 0.15))
                .frame(width: circleSize, height: circleSize)

            Image(emotion.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .frame(width: circleSize, height: circleSize)
                .background {
                    if isSelected {
                        Circle().fill(emotion.color.opacity(0.25))
                    }
                }
                .reveriGlass(.circle, interactive: false)

            Circle()
                .fill(.black.opacity(isDimmed ? 0.55 : 0))
                .frame(width: circleSize, height: circleSize)
                .allowsHitTesting(false)
                .id("dim-\(emotion.id)-\(selectedEmotion?.id ?? "none")")
        }
        .clipShape(Circle())
    }
}
