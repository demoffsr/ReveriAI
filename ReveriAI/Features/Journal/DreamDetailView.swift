import SwiftUI
import SwiftData

struct DreamDetailView: View {
    let dream: Dream
    var folderName: String? = nil
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

    private enum DetailTab: String, CaseIterable {
        case dream = "Dream"
        case meaning = "Meaning"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom nav bar
            navBar

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
                            HStack(spacing: 4) {
                                ForEach(dream.emotions) { emotion in
                                    EmotionTagBadge(emotion: emotion, iconSize: 18, fontSize: 13)
                                }
                            }
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
                }
                .foregroundStyle(.black.opacity(0.35))
                .padding(.top, dream.emotions.isEmpty ? 8 : 12)

                // Segmented control
                Picker("", selection: $selectedTab) {
                    ForEach(DetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Content area
            if selectedTab == .meaning && meaningNeedsCenter {
                meaningContent
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
            } else {
                ScrollView {
                    Group {
                        switch selectedTab {
                        case .dream:
                            Text(dream.text)
                                .font(.system(size: 15))
                                .lineSpacing(4)
                                .tracking(-0.23)
                                .foregroundStyle(.black.opacity(0.8))
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
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            isInDetailDreamTab = true
            detailDreamHasImage = dream.imageURL != nil
            detailDreamIsGenerating = isGenerating
            detailState.isActive = true
            detailState.hasInterpretation = dream.interpretation != nil
            if let text = dream.interpretation {
                cachedParsedSections = parseAndStyleSections(text)
            }
            updateTabBarMode()
        }
        .onDisappear {
            sheetDismissTask?.cancel()
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
        .toast(isPresented: $showImageError, message: "Failed to generate image", icon: "xmark.circle.fill", style: .error, duration: 3.0)
        .sheet(isPresented: $showQuestionsSheet) {
            questionsSheet
        }
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
            } else if let imageURL = dream.imageURL, let url = URL(string: imageURL) {
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

    private var fullscreenImageView: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let imageURL = dream.imageURL, let url = URL(string: imageURL) {
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

    private var navBar: some View {
        HStack {
            // Back button
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

            // Center title
            VStack(spacing: 2) {
                Text("Dream")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.black)

                if let folder = folderName {
                    Text(folder)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black.opacity(0.5))
                }
            }

            Spacer()

            // Right button (options)
            Button {
                // No action yet
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .reveriGlass(.circle)
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
                Text("Add a text description of your dream for interpretation")
                    .font(.system(size: 15))
                    .foregroundStyle(.black.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        } else if detailState.isGeneratingInterpretation {
            centeredPlaceholder {
                ProgressView()
                Text("Interpreting dream...")
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
                    Text("Try again")
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
                Text("Curious what it means?")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Discover the symbols\nand emotions hidden within")
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
            ForEach(cachedParsedSections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    if let title = section.title {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(section.lines) { line in
                            if line.isBullet {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("•")
                                        .font(.subheadline)
                                        .foregroundStyle(.black.opacity(0.8))
                                    line.renderedText
                                }
                            } else {
                                line.renderedText
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

    private struct ParsedLine: Identifiable {
        let id = UUID()
        let isBullet: Bool
        let segments: [TextSegment]
        let renderedText: Text
    }

    private struct ParsedSection: Identifiable {
        let id = UUID()
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
                    let segments = parseBoldSegments(content)
                    return ParsedLine(isBullet: true, segments: segments, renderedText: renderSegments(segments))
                } else {
                    let segments = parseBoldSegments(trimmed)
                    return ParsedLine(isBullet: false, segments: segments, renderedText: renderSegments(segments))
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
            modelContainer: modelContext.container
        ) { imageURL in
            isGenerating = false
            detailDreamHasImage = imageURL != nil
            if imageURL == nil {
                showImageError = true
            }
        }
    }

    private var questionsSheet: some View {
        let isRussian = speechLocale.rawValue.hasPrefix("ru")
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Subtitle
                    Text(isRussian
                         ? "Ответьте на вопросы, чтобы создать более детальную визуализацию вашего сна"
                         : "Answer the questions to create a more detailed visualization of your dream")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    if isLoadingQuestions {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(isRussian ? "Подготовка вопросов..." : "Preparing questions...")
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
                                TextField(isRussian ? "Ваш ответ..." : "Your answer...", text: $answers[index])
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
                            Text(isRussian ? "Сгенерировать" : "Generate")
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
                            Text(isRussian ? "Пропустить" : "Skip")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle(isRussian ? "Визуализация сна" : "Visualize Your Dream")
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
