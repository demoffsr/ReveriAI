import SwiftUI

struct WatchEmotionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WatchThemeManager.self) private var theme
    let onEmotionsSelected: ([DreamEmotion]) -> Void

    @State private var selectedEmotions: Set<DreamEmotion> = []
    @State private var showSavedToast = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("How did it feel?")
                    .font(.headline)
                    .foregroundStyle(theme.accent)
                    .padding(.top, 12)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(DreamEmotion.allCases) { emotion in
                        Button {
                            toggleEmotion(emotion)
                        } label: {
                            emotionCell(emotion)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    Button("Skip") {
                        saveAndDismiss(emotions: [])
                    }
                    .foregroundStyle(theme.accent.opacity(0.5))

                    if !selectedEmotions.isEmpty {
                        Button("Save") {
                            saveAndDismiss(emotions: Array(selectedEmotions))
                        }
                        .foregroundStyle(theme.accent)
                        .fontWeight(.semibold)
                    }
                }
                .padding(.top, 6)
            }
        }
        .overlay(alignment: .top) {
            if showSavedToast {
                WatchToastView()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 4)
            }
        }
        .animation(.spring(duration: 0.4), value: showSavedToast)
        .allowsHitTesting(!showSavedToast)
    }

    private func emotionCell(_ emotion: DreamEmotion) -> some View {
        let isSelected = selectedEmotions.contains(emotion)
        return VStack(spacing: 6) {
            Image(emotion.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
            Text(emotion.displayName)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(emotion.color.opacity(isSelected ? 0.4 : 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isSelected ? emotion.color : emotion.color.opacity(0.3),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                )
        )
    }

    private func toggleEmotion(_ emotion: DreamEmotion) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedEmotions.contains(emotion) {
                selectedEmotions.remove(emotion)
            } else {
                selectedEmotions.insert(emotion)
            }
        }
    }

    private func saveAndDismiss(emotions: [DreamEmotion]) {
        onEmotionsSelected(emotions)
        withAnimation(.spring(duration: 0.4)) {
            showSavedToast = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        }
    }
}

// MARK: - Watch Toast

private struct WatchToastView: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.green)
            Text("Dream saved")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}
