import SwiftUI
import SwiftData

struct DreamDetailView: View {
    let dream: Dream
    var folderName: String? = nil
    @Binding var isInDetailDreamTab: Bool
    @Binding var detailDreamHasImage: Bool
    @Binding var detailDreamIsGenerating: Bool
    @Binding var detailDreamGenerateTrigger: Bool

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

            // Scrollable content
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
                        Text("Coming soon...")
                            .font(.system(size: 15))
                            .foregroundStyle(.black.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            isInDetailDreamTab = true
            detailDreamHasImage = dream.imageURL != nil
            detailDreamIsGenerating = isGenerating
        }
        .onDisappear {
            isInDetailDreamTab = false
        }
        .onChange(of: isGenerating) { _, newValue in
            detailDreamIsGenerating = newValue
        }
        .onChange(of: detailDreamGenerateTrigger) {
            loadQuestions()
        }
        .fullScreenCover(isPresented: $showFullscreenImage) {
            fullscreenImageView
        }
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
                AsyncImage(url: url) { phase in
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
                    default:
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
                AsyncImage(url: url) { phase in
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
