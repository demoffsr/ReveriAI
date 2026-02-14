import SwiftUI
import SwiftData

struct DreamCard: View {
    let dream: Dream
    var onTap: () -> Void = {}
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @State private var showDeleteConfirmation = false

    private var displayTitle: String {
        if !dream.title.isEmpty { return dream.title }
        let words = dream.text.split(separator: " ").prefix(5)
        return words.joined(separator: " ")
    }

    private var audioURL: URL? {
        guard let path = dream.audioFilePath else { return nil }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
        return dir.appendingPathComponent(path)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy, hh:mma"
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text(displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Spacer()

                Menu {
                    Button {
                        // Rename — no-op for now
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button {
                        // Add to Folder — no-op for now
                    } label: {
                        Label("Add to Folder", systemImage: "folder.badge.plus")
                    }
                    Button {
                        // Share — no-op for now
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .reveriGlass(.circle)
                }
            }

            // Emotion pins
            if !dream.emotions.isEmpty {
                HStack(spacing: 4) {
                    ForEach(dream.emotions) { emotion in
                        HStack(spacing: 4) {
                            Image(emotion.iconName)
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(emotion.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(emotion.color)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(height: 24)
                        .background(emotion.color.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, -6)
            }

            // Audio waveform player
            if let audioURL {
                DreamCardPlayer(audioURL: audioURL)
            }

            if !dream.text.isEmpty {
                Text(dream.text)
                    .font(.system(size: 13))
                    .foregroundStyle(.black.opacity(0.5))
                    .lineLimit(2)
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
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture {
            onTap()
        }
        .confirmationDialog("Удалить сон?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                modelContext.delete(dream)
                try? modelContext.save()
            }
            Button("Отмена", role: .cancel) {}
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(Dream.preview, id: \.id) { dream in
                DreamCard(dream: dream)
            }
        }
        .padding()
    }
    .background(Color(white: 0.95))
}
