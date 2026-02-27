import SwiftUI
import SwiftData
import AVFoundation

struct DreamDetailView: View {
    enum EditAction {
        case editText
        case reRecord
    }

    let dream: Dream
    var folderName: String? = nil
    var initialEditAction: EditAction? = nil
    @Binding var isInDetailDreamTab: Bool
    @Binding var detailDreamHasImage: Bool
    @Binding var detailDreamIsGenerating: Bool
    @Binding var detailDreamGenerateTrigger: Bool
    var detailState: DetailDreamState

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: DetailTab = .dream
    @State private var showFullscreenImage = false
    @State private var isGenerating = false
    @State private var showQuestionsSheet = false
    @State private var questions: [String] = []
    @State private var answers: [String] = []
    @State private var isLoadingQuestions = false
    @AppStorage("speechRecognitionLocale") private var speechLocale: SpeechLocale = .russian
    @State private var cachedParsedSections: [ParsedSection] = []
    @State private var showImageError = false
    @State private var sheetDismissTask: Task<Void, Never>?
    @State private var showingOriginal = false
    @State private var cachedAudioURL: URL?
    @State private var cachedDuration: TimeInterval?
    @State private var isEmotionScrolled = false
    @State private var shareAudioURL: URL?
    @State private var isConvertingAudio = false

    // Menu action state
    @State private var showDeleteAlert = false
    @State private var showFolderPicker = false

    // Edit mode state
    @State private var showEmotionPicker = false
    @State private var editingEmotions: Set<DreamEmotion> = []
    @State private var isEditingText = false
    @State private var editableText = ""
    @State private var isReRecording = false
    @State private var editAudioRecorder = AudioRecorder()
    @State private var editWaveformState = WaveformState()
    @State private var editRecordingStartTime: Date?

    private static let recordingsDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
    }()

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private enum DetailTab: String, CaseIterable {
        case dream
        case meaning

        var displayName: String {
            switch self {
            case .dream: String(localized: "detail.tab.dream", defaultValue: "Dream")
            case .meaning: String(localized: "detail.tab.meaning", defaultValue: "Meaning")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom nav bar
            navBar

            if isReRecording {
                reRecordingContent
            } else {
                normalContent
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .onAppear {
            isInDetailDreamTab = true
            detailDreamHasImage = resolvedImageURL != nil
            detailDreamIsGenerating = isGenerating
            detailState.isActive = true
            detailState.hasInterpretation = dream.interpretation != nil
            if let path = dream.audioFilePath {
                let url = Self.recordingsDirectory.appendingPathComponent(path)
                cachedAudioURL = url
                if let stored = dream.audioDuration {
                    cachedDuration = stored
                } else if let player = try? AVAudioPlayer(contentsOf: url) {
                    cachedDuration = player.duration
                }
            }
            if let text = dream.interpretation {
                cachedParsedSections = parseAndStyleSections(text)
            }
            updateTabBarMode()
            if let action = initialEditAction {
                switch action {
                case .editText: enterTextEditMode()
                case .reRecord: enterReRecordMode()
                }
            }
        }
        .onDisappear {
            sheetDismissTask?.cancel()
            if isReRecording { cancelReRecording() }
            isInDetailDreamTab = false
            detailState.isActive = false
            detailState.tabBarMode = .none
        }
        .onChange(of: isGenerating) { _, newValue in
            detailDreamIsGenerating = newValue
        }
        .onChange(of: detailDreamGenerateTrigger) {
            loadQuestions()
        }
        .onChange(of: selectedTab) {
            updateTabBarMode()
        }
        .onChange(of: detailState.interpretTrigger) {
            generateInterpretation()
        }
        .onChange(of: detailState.hasInterpretation) {
            if let text = dream.interpretation {
                cachedParsedSections = parseAndStyleSections(text)
            }
            updateTabBarMode()
        }
        .onChange(of: dream.interpretation) { _, newInterpretation in
            if let text = newInterpretation {
                cachedParsedSections = parseAndStyleSections(text)
            }
            detailState.hasInterpretation = newInterpretation != nil
            updateTabBarMode()
        }
        .fullScreenCover(isPresented: $showFullscreenImage) {
            fullscreenImageView
        }
        .toast(isPresented: $showImageError, message: String(localized: "detail.failedToGenerateImage", defaultValue: "Failed to generate image"), icon: "xmark.circle.fill", style: .error, duration: 3.0)
        .toast(isPresented: Binding(get: { detailState.showRateLimitToast }, set: { detailState.showRateLimitToast = $0 }), message: String(localized: "error.rateLimited"), icon: "clock.badge.exclamationmark", style: .error, duration: 3.0)
        .sheet(isPresented: $showQuestionsSheet) {
            questionsSheet
        }
        .sheet(isPresented: $showEmotionPicker) {
            emotionPickerSheet
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerSheet(dream: dream)
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
        .alert(String(localized: "detail.deleteDream", defaultValue: "Delete dream?"), isPresented: $showDeleteAlert) {
            Button(String(localized: "detail.deleteAction", defaultValue: "Delete"), role: .destructive) {
                HapticService.notification(.warning)
                DreamCleanupService.deleteDream(dream, context: modelContext)
                dismiss()
            }
            Button(String(localized: "detail.cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "detail.deleteMessage", defaultValue: "This action cannot be undone"))
        }
    }

    // MARK: - Normal Content

    private var normalContent: some View {
        VStack(spacing: 0) {
            // Header info (fixed)
            VStack(alignment: .leading, spacing: 0) {
                // Title + thumbnail row
                HStack(alignment: .top, spacing: 12) {
                    // Left: title + emotions
                    VStack(alignment: .leading, spacing: 0) {
                        if !dream.title.isEmpty {
                            Text(dream.title)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.primary)
                        }

                        // Emotion badges
                        if !dream.emotions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(dream.emotions) { emotion in
                                        EmotionTagBadge(emotion: emotion, iconSize: 18, fontSize: 13)
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
                            .padding(.top, 8)
                        }
                    }

                    Spacer()

                    // Right: dream image thumbnail
                    dreamImageThumbnail
                }

                // Date
                HStack(spacing: 4) {
                    Image("CalendarSmallIcon")
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text(dream.createdAt.dreamFormatted)
                        .font(.system(size: 13, weight: .medium))

                    if let cachedDuration {
                        Spacer()
                            .frame(width: 8)
                        Image("ClockSmallIcon")
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(Self.formatDuration(cachedDuration))
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .foregroundStyle(.black.opacity(0.35))
                .padding(.top, dream.emotions.isEmpty ? 8 : 12)

                // Segmented control
                if !isEditingText {
                    Picker("", selection: $selectedTab) {
                        ForEach(DetailTab.allCases, id: \.self) { tab in
                            Text(tab.displayName).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Content area
            if isEditingText {
                textEditContent
            } else if selectedTab == .meaning && meaningNeedsCenter {
                meaningContent
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
            } else {
                ScrollView {
                    Group {
                        switch selectedTab {
                        case .dream:
                            dreamTextContent
                        case .meaning:
                            meaningContent
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    private var resolvedImageURL: URL? {
        // Prefer local file
        if let imagePath = dream.imagePath {
            let localURL = DreamAIService.imagesDirectory.appendingPathComponent(imagePath)
            if FileManager.default.fileExists(atPath: localURL.path) {
                return localURL
            }
        }
        // Fallback to remote URL (old dreams, not yet cached)
        if let imageURL = dream.imageURL {
            return URL(string: imageURL)
        }
        return nil
    }

    @ViewBuilder
    private var dreamImageThumbnail: some View {
        ZStack {
            if isGenerating {
                // Shimmer placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.05))
                    .frame(width: 74, height: 74)
                    .overlay {
                        ProgressView()
                    }
            } else if let url = resolvedImageURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 74, height: 74)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .bottomTrailing) {
                                Button {
                                    showFullscreenImage = true
                                } label: {
                                    Image("FullscreenIcon")
                                        .renderingMode(.original)
                                        .frame(width: 24, height: 24)
                                }
                                .offset(x: -4, y: -4)
                            }
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.black.opacity(0.05))
                            .frame(width: 74, height: 74)
                            .overlay {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.black.opacity(0.3))
                            }
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.black.opacity(0.05))
                            .frame(width: 74, height: 74)
                            .overlay {
                                ProgressView()
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dreamTextContent: some View {
        let displayText = showingOriginal
            ? (dream.originalTranscript ?? dream.text)
            : dream.text

        if displayText.isEmpty && dream.isTranscribingAudio {
            VStack(spacing: 12) {
                ProgressView()
                Text(String(localized: "detail.processing", defaultValue: "Processing recording..."))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Audio waveform player
                if let cachedAudioURL {
                    DreamCardPlayer(audioURL: cachedAudioURL, style: .detail)
                        .padding(.bottom, 20)
                }

                Text(displayText)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .tracking(-0.23)
                    .foregroundStyle(.black.opacity(0.8))

                if dream.hasTranscriptToggle {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingOriginal.toggle()
                        }
                    } label: {
                        Text(showingOriginal ? String(localized: "detail.whisper", defaultValue: "Whisper") : String(localized: "detail.original", defaultValue: "Original"))
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var fullscreenImageView: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let url = resolvedImageURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    default:
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }

            Button {
                showFullscreenImage = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.15)))
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var navBar: some View {
        if isEditingText {
            editingNavBar
        } else if isReRecording {
            reRecordingNavBar
        } else {
            defaultNavBar
        }
    }

    private var defaultNavBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .reveriGlass(.circle)

            Spacer()

            VStack(spacing: 2) {
                Text(String(localized: "detail.navTitle", defaultValue: "Dream"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.black)

                if let folder = folderName {
                    Text(folder)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black.opacity(0.5))
                }
            }

            Spacer()

            Menu {
                Section {
                    if dream.audioFilePath == nil {
                        Button {
                            enterTextEditMode()
                        } label: {
                            Label(String(localized: "detail.updateText", defaultValue: "Update Text"), image: "EditContentIcon")
                        }
                    }
                    if dream.audioFilePath != nil {
                        Button {
                            enterReRecordMode()
                        } label: {
                            Label(String(localized: "detail.recordAgain", defaultValue: "Record Again"), image: "MicrophoneIcon")
                        }
                    }
                    Button {
                        showEmotionPicker = true
                    } label: {
                        Label(String(localized: "detail.changeEmotions", defaultValue: "Change Emotions"), image: "EmotionIcon")
                    }
                    Button {
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
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label(String(localized: "detail.delete", defaultValue: "Delete"), image: "TrashIcon")
                    }
                    .tint(.red)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .tint(theme.accent)
            .reveriGlass(.circle)
        }
        .padding(.horizontal, 16)
    }

    private var editingNavBar: some View {
        HStack {
            Button { cancelTextEdit() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .reveriGlass(.circle)

            Spacer()

            Text(String(localized: "detail.editing", defaultValue: "Editing"))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.black)

            Spacer()

            Button { saveTextEdit() } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(width: 44, height: 44)
            }
            .reveriGlass(.circle)
        }
        .padding(.horizontal, 16)
    }

    private var reRecordingNavBar: some View {
        HStack {
            Button { cancelReRecording() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .reveriGlass(.circle)

            Spacer()

            Text(String(localized: "detail.reRecording", defaultValue: "Re-recording"))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.black)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
    }

    private var meaningNeedsCenter: Bool {
        // Center when there's no scrollable interpretation text
        dream.interpretation == nil
    }

    @ViewBuilder
    private var meaningContent: some View {
        if dream.text.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
            centeredPlaceholder {
                Text(String(localized: "detail.addTextForInterpretation", defaultValue: "Add a text description of your dream for interpretation"))
                    .font(.system(size: 15))
                    .foregroundStyle(.black.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        } else if detailState.isGeneratingInterpretation {
            centeredPlaceholder {
                ProgressView()
                Text(String(localized: "detail.interpretingDream", defaultValue: "Interpreting dream..."))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        } else if let error = detailState.interpretationError {
            centeredPlaceholder {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.black.opacity(0.3))
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    detailState.interpretationError = nil
                    generateInterpretation()
                } label: {
                    Text(String(localized: "detail.tryAgain", defaultValue: "Try again"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
            }
        } else if dream.interpretation != nil, !cachedParsedSections.isEmpty {
            interpretationSectionsView
        } else {
            centeredPlaceholder {
                Image("EmotionJoyful")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                Text(String(localized: "detail.curiousMeaning", defaultValue: "Curious what it means?"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(String(localized: "detail.discoverSymbols", defaultValue: "Discover the symbols\nand emotions hidden within"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func centeredPlaceholder<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var interpretationSectionsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(cachedParsedSections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 6) {
                    if let title = section.title {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                            if line.isBullet {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("•")
                                        .font(.subheadline)
                                        .foregroundStyle(.black.opacity(0.8))
                                    renderSegments(line.segments)
                                }
                            } else {
                                renderSegments(line.segments)
                            }
                        }
                    }
                }
            }
        }
    }

    private func renderSegments(_ segments: [TextSegment]) -> Text {
        segments.reduce(Text("")) { accumulated, segment in
            let segmentText = segment.isBold
                ? Text(segment.text).font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                : Text(segment.text).font(.subheadline).foregroundStyle(.black.opacity(0.8))
            return Text("\(accumulated)\(segmentText)")
        }
    }

    private struct TextSegment {
        let text: String
        let isBold: Bool
    }

    private struct ParsedLine {
        let isBullet: Bool
        let segments: [TextSegment]
    }

    private struct ParsedSection {
        let title: String?
        let lines: [ParsedLine]
    }

    private func parseBoldSegments(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var remaining = text[...]
        while let starRange = remaining.range(of: "**") {
            let before = remaining[remaining.startIndex..<starRange.lowerBound]
            if !before.isEmpty {
                segments.append(TextSegment(text: String(before), isBold: false))
            }
            remaining = remaining[starRange.upperBound...]
            if let endRange = remaining.range(of: "**") {
                segments.append(TextSegment(text: String(remaining[remaining.startIndex..<endRange.lowerBound]), isBold: true))
                remaining = remaining[endRange.upperBound...]
            } else {
                segments.append(TextSegment(text: "**" + String(remaining), isBold: false))
                remaining = remaining[remaining.endIndex...]
            }
        }
        if !remaining.isEmpty {
            segments.append(TextSegment(text: String(remaining), isBold: false))
        }
        return segments
    }

    private func parseAndStyleSections(_ text: String) -> [ParsedSection] {
        let sections = parseInterpretation(text)
        return sections.map { section in
            let lines = section.body.components(separatedBy: "\n").compactMap { line -> ParsedLine? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") {
                    let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                    return ParsedLine(isBullet: true, segments: parseBoldSegments(content))
                } else {
                    return ParsedLine(isBullet: false, segments: parseBoldSegments(trimmed))
                }
            }
            return ParsedSection(title: section.title, lines: lines)
        }
    }

    private struct RawInterpretationSection {
        var title: String?
        var body: String
    }

    private func parseInterpretation(_ text: String) -> [RawInterpretationSection] {
        // Split by numbered headers like "1. **Title**:" or "5. **Key symbols**:"
        let lines = text.components(separatedBy: "\n")
        var sections: [RawInterpretationSection] = []
        var currentTitle: String?
        var currentBody: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Check if line starts a new numbered section
            if let match = trimmed.range(of: #"^\d+\.\s*\*{0,2}([^*:]+?)\*{0,2}\s*:(.*)$"#, options: .regularExpression) {
                // Save previous section
                if currentTitle != nil || !currentBody.isEmpty {
                    sections.append(RawInterpretationSection(
                        title: currentTitle,
                        body: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
                // Extract title and remainder
                let fullMatch = String(trimmed[match])
                // Parse out the title between the number and colon
                if let titleMatch = fullMatch.range(of: #"\d+\.\s*\*{0,2}([^*:]+?)\*{0,2}\s*:"#, options: .regularExpression) {
                    let captured = String(fullMatch[titleMatch])
                    // Remove number prefix and colon suffix
                    let cleaned = captured
                        .replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"\s*:$"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: "**", with: "")
                    currentTitle = cleaned
                }
                // Get text after the colon
                let afterColon = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                currentBody = afterColon.isEmpty ? [] : [afterColon]
            } else {
                currentBody.append(line)
            }
        }
        // Don't forget last section
        if currentTitle != nil || !currentBody.isEmpty {
            sections.append(RawInterpretationSection(
                title: currentTitle,
                body: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        // If parsing found no sections, return entire text as one section
        if sections.isEmpty {
            sections.append(RawInterpretationSection(title: nil, body: text))
        }

        return sections
    }

    // MARK: - Text Edit Mode

    private var textEditContent: some View {
        VStack(spacing: 0) {
            TextEditor(text: $editableText)
                .font(.system(size: 15))
                .lineSpacing(4)
                .tracking(-0.23)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.top, 16)
        }
    }

    private func enterTextEditMode() {
        editableText = dream.text
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditingText = true
        }
    }

    private func cancelTextEdit() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditingText = false
        }
    }

    private func saveTextEdit() {
        let newText = editableText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newText.isEmpty, newText != dream.text else {
            cancelTextEdit()
            return
        }

        // Cleanup old image files
        if let imagePath = dream.imagePath {
            DreamAIService.deleteLocalImage(imagePath: imagePath)
            DreamAIService.deleteImageFromStorage(imagePath: imagePath)
        }

        dream.resetAIContent()
        dream.text = newText
        dream.whisperTranscript = nil
        dream.originalTranscript = nil
        try? modelContext.save()

        // Regenerate title
        DreamAIService.generateTitleInBackground(
            dreamID: dream.persistentModelID,
            dreamText: newText,
            locale: speechLocale,
            modelContainer: modelContext.container
        )

        detailDreamHasImage = false
        cachedParsedSections = []
        updateTabBarMode()

        withAnimation(.easeInOut(duration: 0.2)) {
            isEditingText = false
        }
    }

    // MARK: - Re-Record Mode

    private var reRecordingContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Waveform
            LiveEditWaveformView(
                audioRecorder: editAudioRecorder,
                waveformState: editWaveformState
            )
            .frame(height: 100)
            .padding(.horizontal, 16)

            // Timer
            if let start = editRecordingStartTime {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = Int(context.date.timeIntervalSince(start))
                    let m = elapsed / 60
                    let s = elapsed % 60
                    Text(String(format: "%d:%02d", m, s))
                        .font(.system(size: 48, weight: .light).monospacedDigit())
                        .foregroundStyle(.black.opacity(0.6))
                }
                .padding(.top, 24)
            }

            // Stop button
            Button {
                stopReRecording()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(theme.accent, in: Circle())
            }
            .padding(.top, 32)

            Spacer()
        }
    }

    private func enterReRecordMode() {
        editWaveformState.reset()
        editAudioRecorder.startRecording()
        editRecordingStartTime = .now
        withAnimation(.easeInOut(duration: 0.2)) {
            isReRecording = true
        }
    }

    private func cancelReRecording() {
        let url = editAudioRecorder.stopRecording()
        editRecordingStartTime = nil
        // Delete the new recording
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isReRecording = false
        }
    }

    private func stopReRecording() {
        guard let newURL = editAudioRecorder.stopRecording() else {
            cancelReRecording()
            return
        }
        editRecordingStartTime = nil

        let newFilename = newURL.lastPathComponent

        // Archive old audio
        if let oldPath = dream.audioFilePath {
            AudioArchiveService.archiveAudio(filename: oldPath)
        }

        // Cleanup old image files
        if let imagePath = dream.imagePath {
            DreamAIService.deleteLocalImage(imagePath: imagePath)
            DreamAIService.deleteImageFromStorage(imagePath: imagePath)
        }

        dream.resetAIContent()
        dream.audioFilePath = newFilename
        dream.text = ""
        dream.whisperTranscript = nil
        dream.originalTranscript = nil
        try? modelContext.save()

        // Update cached audio URL
        cachedAudioURL = Self.recordingsDirectory.appendingPathComponent(newFilename)
        detailDreamHasImage = false
        cachedParsedSections = []

        // Transcribe new audio (includes title generation)
        DreamAIService.transcribeAudioInBackground(
            dreamID: dream.persistentModelID,
            audioFileName: newFilename,
            locale: speechLocale,
            modelContainer: modelContext.container
        )

        updateTabBarMode()

        withAnimation(.easeInOut(duration: 0.2)) {
            isReRecording = false
        }
    }

    private func updateTabBarMode() {
        guard detailState.isActive else { return }
        switch selectedTab {
        case .dream:
            if dream.imageURL != nil {
                detailState.tabBarMode = .generateImageAgain
            } else {
                detailState.tabBarMode = .generateImage
            }
        case .meaning:
            if dream.text.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
                detailState.tabBarMode = .none
            } else if dream.interpretation == nil && !detailState.isGeneratingInterpretation {
                detailState.tabBarMode = .interpretDream
            } else {
                detailState.tabBarMode = .none
            }
        }
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

    private func generateInterpretation() {
        guard !detailState.isGeneratingInterpretation else { return }
        detailState.tabBarMode = .none
        DreamAIService.generateInterpretationInBackground(
            dreamID: dream.persistentModelID,
            dreamText: dream.text,
            locale: speechLocale,
            emotions: dream.emotions,
            modelContainer: modelContext.container,
            detailState: detailState
        )
    }

    private func loadQuestions() {
        isLoadingQuestions = true
        showQuestionsSheet = true
        Task {
            do {
                let q = try await DreamAIService.generateQuestions(for: dream.text, locale: speechLocale)
                await MainActor.run {
                    questions = q
                    answers = Array(repeating: "", count: q.count)
                    isLoadingQuestions = false
                }
            } catch let error as DreamAIService.Error where error.isRateLimited {
                await MainActor.run {
                    isLoadingQuestions = false
                    showQuestionsSheet = false
                    detailState.showRateLimitToast = true
                }
            } catch {
                await MainActor.run {
                    isLoadingQuestions = false
                    showQuestionsSheet = false
                }
            }
        }
    }

    private func generateImage(answers: [String]? = nil) {
        guard !isGenerating else { return }
        isGenerating = true
        let filteredAnswers = answers?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let finalAnswers = (filteredAnswers?.isEmpty ?? true) ? nil : filteredAnswers

        DreamAIService.generateImageInBackground(
            dreamID: dream.persistentModelID,
            dreamText: dream.text,
            locale: speechLocale,
            answers: finalAnswers,
            modelContainer: modelContext.container,
            detailState: detailState
        ) { imageURL in
            isGenerating = false
            detailDreamHasImage = imageURL != nil
            if imageURL == nil && !detailState.showRateLimitToast {
                showImageError = true
            }
        }
    }

    private var emotionPickerSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "detail.changeEmotions", defaultValue: "Change Emotions"))
                .font(.system(size: 17, weight: .medium))
                .padding(.horizontal, 20)

            Rectangle()
                .fill(.black.opacity(0.1))
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
        }
    }

    private var questionsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Subtitle
                    Text(String(localized: "detail.questionsSubtitle", defaultValue: "Answer the questions to create a more detailed visualization of your dream"))
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    if isLoadingQuestions {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(String(localized: "detail.preparingQuestions", defaultValue: "Preparing questions..."))
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(questions.indices, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(questions[index])
                                    .font(.system(size: 15, weight: .medium))
                                TextField(String(localized: "detail.yourAnswer", defaultValue: "Your answer..."), text: $answers[index])
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        // Generate button
                        Button {
                            let savedAnswers = answers
                            showQuestionsSheet = false
                            sheetDismissTask?.cancel()
                            sheetDismissTask = Task {
                                try? await Task.sleep(for: .seconds(0.3))
                                guard !Task.isCancelled else { return }
                                generateImage(answers: savedAnswers)
                            }
                        } label: {
                            Text(String(localized: "detail.generate", defaultValue: "Generate"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(theme.accent, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 8)

                        // Skip button
                        Button {
                            showQuestionsSheet = false
                            sheetDismissTask?.cancel()
                            sheetDismissTask = Task {
                                try? await Task.sleep(for: .seconds(0.3))
                                guard !Task.isCancelled else { return }
                                generateImage()
                            }
                        } label: {
                            Text(String(localized: "detail.skip", defaultValue: "Skip"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle(String(localized: "detail.visualizeDream", defaultValue: "Visualize Your Dream"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showQuestionsSheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Isolates high-frequency `audioRecorder.currentLevel` observation (~43Hz)
/// to prevent re-rendering the entire DreamDetailView body.
private struct LiveEditWaveformView: View {
    var audioRecorder: AudioRecorder
    var waveformState: WaveformState

    var body: some View {
        AudioWaveformView(
            isAnimating: audioRecorder.isRecording,
            level: audioRecorder.isRecording ? audioRecorder.currentLevel : 0,
            waveformState: waveformState
        )
    }
}

// MARK: - Activity View Controller

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
