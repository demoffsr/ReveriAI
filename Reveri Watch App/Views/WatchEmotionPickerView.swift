import SwiftUI

struct WatchEmotionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WatchThemeManager.self) private var theme
    let onEmotionSelected: (DreamEmotion?) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Как ощущался сон?")
                    .font(.headline)
                    .foregroundStyle(theme.accent)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(DreamEmotion.allCases) { emotion in
                        Button {
                            onEmotionSelected(emotion)
                            dismiss()
                        } label: {
                            VStack(spacing: 4) {
                                Text(emotion.emoji)
                                    .font(.title2)
                                Text(emotion.displayName)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(emotion.color.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(emotion.color.opacity(0.3), lineWidth: 0.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button("Пропустить") {
                    onEmotionSelected(nil)
                    dismiss()
                }
                .foregroundStyle(theme.accent.opacity(0.5))
                .padding(.top, 4)
            }
        }
    }
}
