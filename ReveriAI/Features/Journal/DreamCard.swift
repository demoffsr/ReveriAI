import SwiftUI
import SwiftData

struct DreamCard: View {
    let dream: Dream
    var onTap: () -> Void = {}
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @State private var showDeleteConfirmation = false
    @State private var showFolderPicker = false
    @State private var cachedDisplayTitle = ""
    @State private var cachedAudioURL: URL?

    private static let recordingsDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
    }()

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
                Text(cachedDisplayTitle)
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
                        showFolderPicker = true
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
                        EmotionTagBadge(emotion: emotion)
                    }
                }
                .padding(.top, -6)
            }

            // Audio waveform player
            if let cachedAudioURL {
                DreamCardPlayer(audioURL: cachedAudioURL)
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
                HapticService.notification(.warning)
                withAnimation(.easeOut(duration: 0.3)) {
                    modelContext.delete(dream)
                    try? modelContext.save()
                }
            }
            Button("Отмена", role: .cancel) {}
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerSheet(dream: dream)
        }
        .onAppear { updateCachedValues() }
        .onChange(of: dream.title) { _, _ in updateCachedValues() }
        .onChange(of: dream.audioFilePath) { _, _ in updateCachedValues() }
    }

    private func updateCachedValues() {
        if !dream.title.isEmpty {
            cachedDisplayTitle = dream.title
        } else {
            let words = dream.text.split(separator: " ").prefix(5)
            cachedDisplayTitle = words.joined(separator: " ")
        }
        if let path = dream.audioFilePath {
            cachedAudioURL = Self.recordingsDirectory.appendingPathComponent(path)
        } else {
            cachedAudioURL = nil
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
