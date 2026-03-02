import SwiftUI

struct EmotionFilterBar: View {
    @Binding var selectedEmotion: DreamEmotion?
    @Binding var emotionOrder: [DreamEmotion]
    @Binding var isExpanded: Bool
    @Environment(\.theme) private var theme

    private let circleSize: CGFloat = 42
    private let collapsedOverlap: CGFloat = 18
    private let expandedSpacing: CGFloat = 6

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: isExpanded ? expandedSpacing : -collapsedOverlap) {
                    ForEach(emotionOrder.indices, id: \.self) { index in
                        let emotion = emotionOrder[index]
                        emotionCircle(emotion)
                            .animation(nil, value: selectedEmotion)
                            .id(emotion.id)
                            .zIndex(isExpanded ? 0 : Double(emotionOrder.count - index))
                            .onTapGesture {
                                if isExpanded {
                                    selectEmotion(emotion)
                                } else {
                                    HapticService.impact(.light)
                                    withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                                        isExpanded = true
                                    }
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
                HapticService.impact(.light)
                withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                    isExpanded = true
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: circleSize)
    }

    private func selectEmotion(_ emotion: DreamEmotion) {
        HapticService.selection()
        let isDeselecting = selectedEmotion == emotion

        selectedEmotion = isDeselecting ? nil : emotion
        AnalyticsService.track(.emotionFilterChanged, metadata: [
            "emotion": isDeselecting ? "none" : emotion.rawValue
        ])

        withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
            if !isDeselecting {
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
                    .transition(.identity)
            }

            if isDimmed {
                Circle()
                    .fill(.black.opacity(0.55))
                    .frame(width: circleSize, height: circleSize)
                    .allowsHitTesting(false)
                    .transition(.identity)
            }

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
