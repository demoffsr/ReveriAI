import SwiftUI
import SwiftData
import AVFoundation

struct DreamCard: View {
    let dream: Dream
    var onTap: () -> Void = {}
    var onEdit: () -> Void = {}
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @State private var showDeleteConfirmation = false
    @State private var showFolderPicker = false
    @State private var cachedDisplayTitle = ""
    @State private var cachedAudioURL: URL?
    @State private var cachedDuration: TimeInterval?
    @State private var isEmotionScrolled = false

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
                        onEdit()
                    } label: {
                        Label(String(localized: "dreamCard.edit", defaultValue: "Edit"), systemImage: "pencil")
                    }
                    Button {
                        // Rename — no-op for now
                    } label: {
                        Label(String(localized: "dreamCard.rename", defaultValue: "Rename"), systemImage: "character.cursor.ibeam")
                    }
                    Button {
                        showFolderPicker = true
                    } label: {
                        Label(String(localized: "dreamCard.addToFolder", defaultValue: "Add to Folder"), systemImage: "folder.badge.plus")
                    }
                    Button {
                        // Share — no-op for now
                    } label: {
                        Label(String(localized: "dreamCard.share", defaultValue: "Share"), systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label(String(localized: "dreamCard.delete", defaultValue: "Delete"), systemImage: "trash")
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

            // Audio waveform player
            if let cachedAudioURL {
                DreamCardPlayer(audioURL: cachedAudioURL)
            }

            if !dream.text.isEmpty {
                Text(dream.text)
                    .font(.system(size: 13))
                    .foregroundStyle(.black.opacity(0.5))
                    .lineLimit(2)
            } else if dream.isTranscribingAudio {
                Text(String(localized: "dreamCard.processing", defaultValue: "Processing recording..."))
                    .font(.system(size: 13).italic())
                    .foregroundStyle(.black.opacity(0.35))
                    .phaseAnimator([false, true]) { content, phase in
                        content.opacity(phase ? 0.4 : 1.0)
                    } animation: { _ in
                        .easeInOut(duration: 1.2)
                    }
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

                if let cachedDuration {
                    Spacer()
                        .frame(width: 8)
                    Image("ClockSmallIcon")
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(Self.formatDuration(cachedDuration))
                        .font(.system(size: 13))
                }
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
        .confirmationDialog(String(localized: "dreamCard.deleteConfirmation", defaultValue: "Delete dream?"), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(String(localized: "dreamCard.deleteAction", defaultValue: "Delete"), role: .destructive) {
                HapticService.notification(.warning)
                DreamCleanupService.deleteDream(dream, context: modelContext)
            }
            Button(String(localized: "dreamCard.cancel", defaultValue: "Cancel"), role: .cancel) {}
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerSheet(dream: dream)
        }
        .onAppear { updateCachedValues() }
        .onChange(of: dream.title) { _, _ in updateCachedValues() }
        .onChange(of: dream.audioFilePath) { _, _ in updateCachedValues() }
        .onChange(of: dream.whisperTranscript) { _, _ in updateCachedValues() }
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func updateCachedValues() {
        if !dream.title.isEmpty {
            cachedDisplayTitle = dream.title
        } else {
            let words = dream.text.split(separator: " ").prefix(5)
            cachedDisplayTitle = words.joined(separator: " ")
        }
        if let path = dream.audioFilePath {
            let url = Self.recordingsDirectory.appendingPathComponent(path)
            cachedAudioURL = url
            if let stored = dream.audioDuration {
                cachedDuration = stored
            } else if let player = try? AVAudioPlayer(contentsOf: url) {
                cachedDuration = player.duration
            }
        } else {
            cachedAudioURL = nil
            cachedDuration = nil
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
