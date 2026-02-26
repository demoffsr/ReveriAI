import SwiftUI

struct SearchDreamRow: View {
    let dream: Dream
    var onTap: () -> Void
    @State private var isEmotionScrolled = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy, hh:mma"
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Title
                Text(displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                // Emotion pins
                if !dream.emotions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(dream.emotions) { emotion in
                                EmotionTagBadge(emotion: emotion)
                            }
                        }
                    }
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        geometry.contentOffset.x > 2
                    } action: { _, scrolled in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEmotionScrolled = scrolled
                        }
                    }
                    .mask(
                        HStack(spacing: 0) {
                            if isEmotionScrolled {
                                LinearGradient(colors: [.clear, .black],
                                               startPoint: .leading, endPoint: .trailing)
                                    .frame(width: 12)
                            }
                            Color.black
                        }
                    )
                    .padding(.top, -6)
                }

                // Divider
                Rectangle()
                    .fill(.black.opacity(0.15))
                    .frame(height: 0.5)

                // Date row
                HStack(spacing: 4) {
                    Image("CalendarSmallIcon")
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(Self.dateFormatter.string(from: dream.createdAt))
                        .font(.system(size: 13))
                }
                .foregroundStyle(.black.opacity(0.35))
            }
            .padding(14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.black.opacity(0.1), lineWidth: 1)
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
