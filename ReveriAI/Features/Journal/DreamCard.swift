import SwiftUI
import SwiftData
import AVFoundation

struct DreamCard: View {
    let dream: Dream
    var isArchiveMode: Bool = false
    var onTap: () -> Void = {}
    var onEditAction: ((DreamDetailView.EditAction) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @AppStorage("speechRecognitionLocale") private var speechLocale: SpeechLocale = .russian
    @State private var showDeleteConfirmation = false
    @State private var showFolderPicker = false
    @State private var showEmotionPicker = false
    @State private var editingEmotions: Set<DreamEmotion> = []
    @State private var cachedDisplayTitle = ""
    @State private var cachedAudioURL: URL?
    @State private var cachedDuration: TimeInterval?
    @State private var isEmotionScrolled = false
    @State private var shareAudioURL: URL?
    @State private var isConvertingAudio = false

    private static let recordingsDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(cachedDisplayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1...2)

                Spacer()

                Menu {
                    Section {
                        if dream.audioFilePath == nil {
                            Button {
                                AnalyticsService.track(.dreamEdited, metadata: ["action": "edit_text"])
                                onEditAction?(.editText)
                            } label: {
                                Label(String(localized: "detail.updateText", defaultValue: "Update Text"), image: "EditContentIcon")
                            }
                        }
                        if dream.audioFilePath != nil {
                            Button {
                                AnalyticsService.track(.dreamEdited, metadata: ["action": "re_record"])
                                onEditAction?(.reRecord)
                            } label: {
                                Label(String(localized: "detail.recordAgain", defaultValue: "Record Again"), image: "MicrophoneIcon")
                            }
                        }
                        Button {
                            AnalyticsService.track(.dreamEdited, metadata: ["action": "change_emotions"])
                            showEmotionPicker = true
                        } label: {
                            Label(String(localized: "detail.changeEmotions", defaultValue: "Change Emotions"), image: "EmotionIcon")
                        }
                        Button {
                            AnalyticsService.track(.dreamEdited, metadata: ["action": "rename"])
                            onEditAction?(.renameTitle)
                        } label: {
                            Label(String(localized: "detail.renameDream", defaultValue: "Rename Dream"), image: "RenameIcon")
                        }
                        Button {
                            AnalyticsService.track(.aiTitleRegenerated)
                            regenerateTitle()
                        } label: {
                            Label(String(localized: "detail.generateName", defaultValue: "Generate Name"), image: "GenerateNameIcon")
                        }
                    }
                    Section {
                        ShareLink(item: dream.text) {
                            Label(String(localized: "detail.shareDream", defaultValue: "Share Dream"), image: "ShareDreamIcon")
                        }
                        if cachedAudioURL != nil {
                            Button {
                                AnalyticsService.track(.dreamShared, metadata: ["type": "audio"])
                                convertAndShareAudio()
                            } label: {
                                Label(String(localized: "detail.shareAudio", defaultValue: "Share Audio"), image: "SoundWaveIcon")
                            }
                            .disabled(isConvertingAudio)
                        }
                        Button {
                            showFolderPicker = true
                        } label: {
                            Label(String(localized: "detail.addToFolder", defaultValue: "Add to Folder"), image: "FolderOpenIcon")
                        }
                    }
                    Section {
                        if isArchiveMode {
                            Button {
                                HapticService.notification(.success)
                                DreamCleanupService.restoreDream(dream, context: modelContext)
                            } label: {
                                Label(String(localized: "dreamCard.restore", defaultValue: "Restore"), image: "RestartIcon")
                            }
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label(String(localized: "dreamCard.delete", defaultValue: "Delete"), image: "TrashIcon")
                            }
                            .tint(.red)
                        } else {
                            Button(role: .destructive) {
                                HapticService.notification(.warning)
                                DreamCleanupService.archiveDream(dream, context: modelContext)
                            } label: {
                                Label(String(localized: "dreamCard.archive", defaultValue: "Archive"), image: "BoxIcon")
                            }
                            .tint(.red)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.textPrimary.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(theme.isDayTime ? .clear : Color(white: 0.25))
                        .clipShape(Circle())
                        .contentShape(Circle().size(width: 44, height: 44))
                        .reveriGlass(.circle)
                }
                .tint(theme.accent)
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
                .padding(.top, 0)
            }

            // Audio waveform player
            if let cachedAudioURL {
                DreamCardPlayer(audioURL: cachedAudioURL)
            }

            if !dream.text.isEmpty {
                Text(dream.text)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            } else if dream.isTranscribingAudio {
                Text(String(localized: "dreamCard.processing", defaultValue: "Processing recording..."))
                    .font(.system(size: 13).italic())
                    .foregroundStyle(theme.textTertiary)
                    .phaseAnimator([false, true]) { content, phase in
                        content.opacity(phase ? 0.4 : 1.0)
                    } animation: { _ in
                        .easeInOut(duration: 1.2)
                    }
            }

            // Divider
            Rectangle()
                .fill(theme.dividerColor)
                .frame(height: 0.5)

            // Date row
            HStack(spacing: 4) {
                Image("CalendarSmallIcon")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 16, height: 16)
                Text(Self.dateFormatter.string(from: dream.createdAt))
                    .font(.system(size: 13))

                if let cachedDuration {
                    Spacer()
                        .frame(width: 8)
                    Image("ClockSmallIcon")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 16, height: 16)
                    Text(Self.formatDuration(cachedDuration))
                        .font(.system(size: 13))
                }
            }
            .foregroundStyle(theme.textSecondary)
        }
        .padding(14)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(theme.cardStroke, lineWidth: 1)
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
        .sheet(isPresented: $showEmotionPicker) {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "detail.changeEmotions", defaultValue: "Change Emotions"))
                    .font(.system(size: 17, weight: .medium))
                    .padding(.horizontal, 20)

                Rectangle()
                    .fill(theme.cardStroke)
                    .frame(height: 1)

                EmotionPickerGrid(selectedEmotions: $editingEmotions)
                    .padding(.bottom, 8)
            }
            .padding(.top, 20)
            .presentationDetents([.height(220)])
            .onAppear {
                editingEmotions = Set(dream.emotions)
            }
            .onChange(of: editingEmotions) {
                dream.emotions = Array(editingEmotions)
                try? modelContext.save()
                AnalyticsService.track(.dreamEmotionsChanged, metadata: [
                    "count": editingEmotions.count
                ])
            }
        }
        .sheet(isPresented: Binding(
            get: { shareAudioURL != nil },
            set: { if !$0 { shareAudioURL = nil } }
        )) {
            if let url = shareAudioURL {
                ActivityViewController(activityItems: [url])
                    .presentationDetents([.medium, .large])
            }
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

    private func regenerateTitle() {
        dream.title = ""
        try? modelContext.save()
        DreamAIService.generateTitleInBackground(
            dreamID: dream.persistentModelID,
            dreamText: dream.text,
            locale: speechLocale,
            modelContainer: modelContext.container
        )
    }

    private func convertAndShareAudio() {
        guard let audioURL = cachedAudioURL else { return }
        isConvertingAudio = true
        Task {
            do {
                let voiceURL = try await AudioConversionService.prepareForShare(source: audioURL)
                shareAudioURL = voiceURL
            } catch {
                shareAudioURL = audioURL
            }
            isConvertingAudio = false
        }
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
