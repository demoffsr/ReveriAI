import SwiftUI

struct EmotionFilterBar: View {
    @Binding var selectedEmotion: DreamEmotion?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(DreamEmotion.allCases) { emotion in
                Text(emotion.emoji)
                    .font(.system(size: 18))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(selectedEmotion == emotion ? emotion.color.opacity(0.3) : .clear)
                    )
                    .overlay(
                        Circle()
                            .stroke(selectedEmotion == emotion ? emotion.color : .clear, lineWidth: 1.5)
                    )
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.25)) {
                            if selectedEmotion == emotion {
                                selectedEmotion = nil
                            } else {
                                selectedEmotion = emotion
                            }
                        }
                    }
            }
        }
    }
}
