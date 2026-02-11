import SwiftUI
import SwiftData

struct EmotionGrid: View {
    let dream: Dream?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedEmotion: DreamEmotion?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("How did it feel?")
                    .font(.title2.weight(.bold))
                Text("Select the emotion that best describes your dream")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            // Emotion grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                spacing: 16
            ) {
                ForEach(DreamEmotion.allCases) { emotion in
                    EmotionBadge(
                        emotion: emotion,
                        isSelected: selectedEmotion == emotion
                    )
                    .onTapGesture {
                        selectedEmotion = emotion
                        saveEmotion(emotion)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func saveEmotion(_ emotion: DreamEmotion) {
        dream?.emotion = emotion
        try? modelContext.save()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            dismiss()
        }
    }
}
