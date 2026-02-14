import SwiftUI
import SwiftData

struct DreamCard: View {
    let dream: Dream
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @State private var showDeleteConfirmation = false

    private var displayTitle: String {
        if !dream.title.isEmpty { return dream.title }
        let words = dream.text.split(separator: " ").prefix(5)
        return words.joined(separator: " ")
    }

    private var hasAudio: Bool {
        dream.audioFilePath != nil
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
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        // Edit — no-op for now
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .background(Color(white: 0.95))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.black.opacity(0.05), lineWidth: 1))
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
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(emotion.color)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .frame(height: 24)
                        .background(emotion.color.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
            }

            // Content
            if hasAudio {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(theme.accent)
                        .clipShape(Circle())

                    HStack(spacing: 2) {
                        ForEach(0..<20, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.black.opacity(0.15))
                                .frame(width: 2, height: .random(in: 6...18))
                        }
                    }

                    Spacer()

                    Text("0:00")
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.35))
                }
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
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                Text(Self.dateFormatter.string(from: dream.createdAt).lowercased())
                    .font(.system(size: 12, weight: .medium))
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
