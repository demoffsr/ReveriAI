import SwiftUI
import SwiftData

struct EditDreamSheet: View {
    let dream: Dream
    var onEditText: () -> Void
    var onReRecord: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @State private var selectedEmotions: Set<DreamEmotion> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(String(localized: "editDream.title", defaultValue: "Edit your dream"))
                .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.top, 20)

            // Action buttons
            VStack(spacing: 12) {
                actionButton(
                    title: String(localized: "editDream.writeAgain", defaultValue: "Write again"),
                    iconName: "TextModeIcon",
                    action: {
                        dismiss()
                        onEditText()
                    }
                )

                if dream.audioFilePath != nil {
                    actionButton(
                        title: String(localized: "editDream.recordAgain", defaultValue: "Record again"),
                        iconName: "VoiceModeIcon",
                        action: {
                            dismiss()
                            onReRecord()
                        }
                    )
                }
            }
            .padding(.horizontal, 20)

            // Emotion carousel
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "editDream.changeEmotions", defaultValue: "Change emotions"))
                    .font(.system(size: 15, weight: .medium))
                    .tracking(-0.23)
                    .foregroundStyle(.black.opacity(0.6))
                    .padding(.horizontal, 20)

                EmotionCarousel(selectedEmotions: $selectedEmotions)
            }

        }
        .presentationDetents([.medium])
        .onAppear {
            selectedEmotions = Set(dream.emotions)
        }
        .onChange(of: selectedEmotions) { _, newValue in
            dream.emotions = Array(newValue)
            try? modelContext.save()
        }
    }

    private func actionButton(title: String, iconName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(iconName)
                    .renderingMode(.template)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.black)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.black.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
