import SwiftUI

struct DreamCard: View {
    let dream: Dream
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: emotion + Interpret button
            HStack {
                if let emotion = dream.emotion {
                    HStack(spacing: 6) {
                        Text(emotion.emoji)
                            .font(.title3)
                        Text(emotion.displayName)
                            .font(.subheadline.weight(.semibold))
                    }
                }

                Spacer()

                Button {
                    // Future: navigate to interpretation
                } label: {
                    HStack(spacing: 2) {
                        Text("Interpret")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }

            // Dream text preview
            Text(dream.text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Bottom row: date + translated badge
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(dream.createdAt.dreamFormatted)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if dream.isTranslated {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text("Translated")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(theme.accent)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}
