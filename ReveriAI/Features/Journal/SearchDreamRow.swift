import SwiftUI

struct SearchDreamRow: View {
    let dream: Dream
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                if !dream.emotions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(dream.emotions.prefix(3)) { emotion in
                            EmotionTagBadge(emotion: emotion, iconSize: 12, fontSize: 11)
                        }
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11))
                        .foregroundStyle(.black.opacity(0.35))
                    Text(dream.createdAt.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                        .font(.system(size: 11))
                        .foregroundStyle(.black.opacity(0.35))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var displayTitle: String {
        if !dream.title.isEmpty {
            return dream.title
        }
        let words = dream.text.split(separator: " ").prefix(5)
        let truncated = words.joined(separator: " ")
        return words.count >= 5 ? truncated + "..." : truncated
    }
}
