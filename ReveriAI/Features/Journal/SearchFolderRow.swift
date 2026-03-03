import SwiftUI

struct SearchFolderRow: View {
    let folder: DreamFolder
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                emotionIcons

                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                    Text(String(localized: "\(folder.dreams.count) Dreams"))
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.4))
                }

                Spacer(minLength: 0)
            }
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

    @ViewBuilder
    private var emotionIcons: some View {
        let topEmotions = Self.computeTopEmotions(from: folder.dreams)
        if !topEmotions.isEmpty {
            let circleSize: CGFloat = 24
            let offset: CGFloat = 14
            let totalWidth = circleSize + offset * CGFloat(topEmotions.count - 1)

            ZStack(alignment: .leading) {
                ForEach(Array(topEmotions.enumerated()), id: \.element) { index, emotion in
                    Image(emotion.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .frame(width: circleSize, height: circleSize)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 0.5))
                        .offset(x: CGFloat(index) * offset)
                        .zIndex(Double(topEmotions.count - index))
                }
            }
            .frame(width: totalWidth, height: circleSize, alignment: .leading)
        }
    }

    private static func computeTopEmotions(from dreams: [Dream]) -> [DreamEmotion] {
        var counts: [DreamEmotion: Int] = [:]
        for dream in dreams {
            for emotion in dream.emotions {
                counts[emotion, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key)
    }
}
