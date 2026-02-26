import SwiftUI
import SwiftData

struct FolderCard: View {
    let folder: DreamFolder
    var onTap: () -> Void = {}
    var onRename: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var cachedEmotions: [DreamEmotion] = []

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top area: "Add dreams" hint or emotion icons (fixed 32pt height)
            if folder.dreams.isEmpty {
                Text(String(localized: "folder.addDreamsHint", defaultValue: "Add dreams"))
                    .font(.system(size: 13).italic())
                    .foregroundStyle(.black.opacity(0.3))
                    .frame(height: 32, alignment: .center)
            } else {
                emotionIcons
            }

            Spacer(minLength: 0)

            // Bottom: name + count + ellipsis (aligned to top)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                    Text(String(localized: "\(folder.dreams.count) Dreams"))
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.5))
                }

                Spacer()

                Menu {
                    Button {
                        onRename()
                    } label: {
                        Label(String(localized: "folder.rename", defaultValue: "Rename"), systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        HapticService.notification(.warning)
                        onDelete()
                    } label: {
                        Label(String(localized: "folder.delete", defaultValue: "Delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.4))
                        .frame(width: 30, height: 30)
                        .reveriGlass(.circle)
                }
            }
        }
        .padding(14)
        .frame(minHeight: 117)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.black.opacity(0.1), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            onTap()
        }
        .task(id: folder.dreams.count) {
            cachedEmotions = Self.computeTopEmotions(from: folder.dreams)
        }
    }

    @ViewBuilder
    private var emotionIcons: some View {
        let emotions = cachedEmotions
        if !emotions.isEmpty {
            // Overlapping circles: 32pt each, 18pt offset (14pt overlap)
            let circleSize: CGFloat = 32
            let offset: CGFloat = 18
            let totalWidth = circleSize + offset * CGFloat(emotions.count - 1)

            ZStack(alignment: .leading) {
                ForEach(Array(emotions.enumerated()), id: \.element) { index, emotion in
                    Image(emotion.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .frame(width: circleSize, height: circleSize)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 0.75))
                        .offset(x: CGFloat(index) * offset)
                        .zIndex(Double(emotions.count - index))
                }
            }
            .frame(width: totalWidth, height: circleSize, alignment: .leading)
        }
    }
}
