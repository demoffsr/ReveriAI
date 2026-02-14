import SwiftUI

struct EmotionFilterBar: View {
    @Binding var selectedEmotion: DreamEmotion?
    @Environment(\.theme) private var theme
    @State private var isExpanded = false

    var body: some View {
        if isExpanded {
            GlassEffectContainer(spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(DreamEmotion.allCases) { emotion in
                            emotionCircle(emotion)
                                .onTapGesture {
                                    withAnimation(.spring(duration: 0.3)) {
                                        if selectedEmotion == emotion {
                                            selectedEmotion = nil
                                        } else {
                                            selectedEmotion = emotion
                                        }
                                        isExpanded = false
                                    }
                                }
                        }
                    }
                }
            }
            .transition(.blurReplace)
        } else {
            HStack(spacing: -14) {
                ForEach(Array(DreamEmotion.allCases.enumerated()), id: \.element.id) { index, emotion in
                    emotionCircle(emotion)
                        .zIndex(Double(DreamEmotion.allCases.count - index))
                }
            }
            .onTapGesture {
                withAnimation(.spring(duration: 0.3)) {
                    isExpanded = true
                }
            }
            .transition(.blurReplace)
        }
    }

    private func emotionCircle(_ emotion: DreamEmotion) -> some View {
        Image(emotion.iconName)
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)
            .frame(width: 40, height: 40)
            .reveriGlass(.circle)
            .overlay(
                Circle()
                    .stroke(selectedEmotion == emotion ? theme.accent : .clear, lineWidth: 2)
            )
    }
}
