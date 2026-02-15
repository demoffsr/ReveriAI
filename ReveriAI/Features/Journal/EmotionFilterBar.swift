import SwiftUI

struct EmotionFilterBar: View {
    @Binding var selectedEmotion: DreamEmotion?
    @Binding var emotionOrder: [DreamEmotion]
    @Binding var isExpanded: Bool
    @Environment(\.theme) private var theme

    private let circleSize: CGFloat = 42
    private let collapsedOverlap: CGFloat = 16
    private let expandedSpacing: CGFloat = 6

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: isExpanded ? expandedSpacing : -collapsedOverlap) {
                    ForEach(emotionOrder.indices, id: \.self) { index in
                        let emotion = emotionOrder[index]
                        emotionCircle(emotion)
                            .id(emotion.id)
                            .zIndex(isExpanded ? 0 : Double(emotionOrder.count - index))
                            .onTapGesture {
                                if isExpanded {
                                    selectEmotion(emotion)
                                } else {
                                    isExpanded = true
                                }
                            }
                    }
                }
                .padding(.trailing, isExpanded ? 20 : 0)
            }
            .scrollDisabled(!isExpanded)
            .scrollClipDisabled()
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: isExpanded ? 0.12 : 0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .contentMargins(.leading, 0)
            .onChange(of: isExpanded) { _, newValue in
                if !newValue {
                    proxy.scrollTo(emotionOrder.first?.id, anchor: .leading)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isExpanded {
                isExpanded = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: circleSize)
        .animation(.spring(duration: 0.4, bounce: 0.15), value: isExpanded)
    }

    private func selectEmotion(_ emotion: DreamEmotion) {
        if selectedEmotion == emotion {
            selectedEmotion = nil
        } else {
            selectedEmotion = emotion
            emotionOrder.removeAll { $0 == emotion }
            emotionOrder.insert(emotion, at: 0)
        }
        isExpanded = false
    }

    private func emotionCircle(_ emotion: DreamEmotion) -> some View {
        let isSelected = selectedEmotion == emotion
        let isDimmed = selectedEmotion != nil && !isSelected

        return ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: circleSize, height: circleSize)

            Image(emotion.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)

            if isSelected {
                Circle()
                    .fill(emotion.color.opacity(0.25))
                    .frame(width: circleSize, height: circleSize)
            }

            Circle()
                .fill(.black.opacity(isDimmed ? 0.55 : 0))
                .frame(width: circleSize, height: circleSize)
                .allowsHitTesting(false)
                .id("dim-\(emotion.id)-\(selectedEmotion?.id ?? "none")")

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
                .frame(width: circleSize - 0.75, height: circleSize - 0.75)
        }
        .frame(width: circleSize, height: circleSize)
        .clipShape(Circle())
    }
}
