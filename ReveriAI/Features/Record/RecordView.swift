import SwiftUI
import SwiftData
import AVFoundation

// MARK: - RecordCardShape (matches Figma SVG: stepped top with bump on right)

private struct RecordCardShape: Shape {
    let stepHeight: CGFloat
    let stepXFraction: CGFloat
    let cornerRadius: CGFloat
    let transitionRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cr = cornerRadius
        let tr = transitionRadius
        let stepY = stepHeight
        let stepX = w * stepXFraction
        let bumpLeftX = stepX + tr

        var path = Path()

        // Clockwise from bottom-left
        path.move(to: CGPoint(x: 0, y: h - cr))

        // Bottom-left corner
        path.addArc(tangent1End: CGPoint(x: 0, y: h),
                     tangent2End: CGPoint(x: cr, y: h),
                     radius: cr)

        // Bottom edge → bottom-right corner
        path.addArc(tangent1End: CGPoint(x: w, y: h),
                     tangent2End: CGPoint(x: w, y: h - cr),
                     radius: cr)

        // Right edge up → top-right corner
        path.addArc(tangent1End: CGPoint(x: w, y: 0),
                     tangent2End: CGPoint(x: w - cr, y: 0),
                     radius: cr)

        // Bump top edge left → bump top-left corner (turning down)
        path.addArc(tangent1End: CGPoint(x: bumpLeftX, y: 0),
                     tangent2End: CGPoint(x: bumpLeftX, y: stepY),
                     radius: cr)

        // Vertical step → concave transition (turning left)
        path.addArc(tangent1End: CGPoint(x: bumpLeftX, y: stepY),
                     tangent2End: CGPoint(x: 0, y: stepY),
                     radius: tr)

        // Step edge left → top-left corner (turning down)
        path.addArc(tangent1End: CGPoint(x: 0, y: stepY),
                     tangent2End: CGPoint(x: 0, y: stepY + cr),
                     radius: cr)

        path.closeSubpath()
        return path
    }
}

// MARK: - RecordView

struct RecordView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @AppStorage("speechRecognitionLocale") private var selectedLocaleId: String = SpeechLocale.defaultLocale.identifier
    @State private var viewModel = RecordViewModel()
    @FocusState private var isTextFocused: Bool

    @Binding var isRecording: Bool
    @Binding var isPaused: Bool
    @Binding var isReviewing: Bool
    @State private var elapsedSeconds: Int = 0
    @State private var totalRecordingSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var reviewText: String = ""
    var audioRecorder: AudioRecorder
    var speechService: SpeechRecognitionService
    var isVisible: Bool = true
    var liveActivityManager: LiveActivityManager?

    var onDreamSaved: ((Dream) -> Void)?
    var onShowHowDidItFeel: (() -> Void)?

    init(
        isRecording: Binding<Bool>,
        isPaused: Binding<Bool>,
        isReviewing: Binding<Bool>,
        audioRecorder: AudioRecorder,
        speechService: SpeechRecognitionService,
        isVisible: Bool = true,
        liveActivityManager: LiveActivityManager? = nil,
        onDreamSaved: ((Dream) -> Void)? = nil,
        onShowHowDidItFeel: (() -> Void)? = nil
    ) {
        self._isRecording = isRecording
        self._isPaused = isPaused
        self._isReviewing = isReviewing
        self.audioRecorder = audioRecorder
        self.speechService = speechService
        self.isVisible = isVisible
        self.liveActivityManager = liveActivityManager
        self.onDreamSaved = onDreamSaved
        self.onShowHowDidItFeel = onShowHowDidItFeel
    }

    // Shape constants (from Figma SVG: 350×754.5 viewBox)
    private let stepHeight: CGFloat = 53
    private let stepXFraction: CGFloat = 197.5 / 350
    private let cardCornerRadius: CGFloat = 16
    private let stepTransitionRadius: CGFloat = 12

    private var selectedLocale: SpeechLocale {
        SpeechLocale(rawValue: selectedLocaleId) ?? .defaultLocale
    }

    private var cardShape: RecordCardShape {
        RecordCardShape(
            stepHeight: stepHeight,
            stepXFraction: stepXFraction,
            cornerRadius: cardCornerRadius,
            transitionRadius: stepTransitionRadius
        )
    }

    var body: some View {
        ZStack {
            theme.screenBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .zIndex(1)

                contentCard
                    .padding(.horizontal, 16)
                    .offset(y: -stepHeight)
                    .padding(.bottom, -stepHeight)
            }
        }
        .onAppear {
            viewModel.onDreamSaved = onDreamSaved
            viewModel.onShowHowDidItFeel = onShowHowDidItFeel
        }
        .onChange(of: isRecording) { _, newValue in
            if !newValue { handleStop() }
        }
        .onChange(of: isPaused) { _, paused in
            if isRecording {
                if paused {
                    audioRecorder.pauseRecording()
                    speechService.pauseTranscription()
                    liveActivityManager?.pause(elapsedSeconds: elapsedSeconds)
                } else {
                    audioRecorder.resumeRecording()
                    liveActivityManager?.resume(elapsedSeconds: elapsedSeconds)
                }
            }
        }
        .onChange(of: isReviewing) { _, newValue in
            if !newValue {
                handleDelete()
            }
        }
        .onChange(of: selectedLocaleId, initial: true) { _, newValue in
            viewModel.speechLocaleRaw = newValue
        }
    }

    // MARK: - Top Bar (avatar + title + right control — all in one row for alignment)

    private var topBar: some View {
        HStack {
            Menu {
                ForEach(SpeechLocale.allCases) { locale in
                    Button {
                        selectedLocaleId = locale.identifier
                    } label: {
                        HStack {
                            Text(locale.displayName)
                            if locale == selectedLocale {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .reveriGlass(.circle)
            }

            Text("Your Dreams")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(theme.accent)

            Spacer()

            rightControl
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: isRecording)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: isReviewing)
        .animation(.easeOut(duration: 0.25), value: viewModel.canSave)
        .animation(.easeOut(duration: 0.25), value: viewModel.mode)
    }

    // MARK: - Content Card (custom shape, content only)

    private var contentCard: some View {
        VStack(spacing: 0) {
            // Reserve bump area (topBar right control visually sits here)
            Spacer().frame(height: stepHeight + 8)

            // Main content
            Group {
                if viewModel.mode == .text && !isRecording && !isReviewing {
                    textModeContent
                } else {
                    voiceModeContent
                }
            }
            .padding(.bottom, 120) // tab bar clearance
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardShape.fill(theme.cardBackground))
        .clipShape(cardShape)
    }

    // MARK: - Right Control (in bump area)

    @ViewBuilder
    private var rightControl: some View {
        if isReviewing {
            SaveDreamButton { handleSaveAudio() }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else if !isRecording && viewModel.mode == .text && viewModel.canSave {
            SaveDreamButton {
                viewModel.saveDream(context: modelContext)
                isTextFocused = false
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else if !isRecording && !isReviewing {
            modeSwitchPill
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    // MARK: - Text Mode Content

    private var textModeContent: some View {
        TextModeView(text: $viewModel.dreamText, isFocused: $isTextFocused)
    }

    // MARK: - Voice Mode Content

    private var voiceModeContent: some View {
        VStack(spacing: 0) {
            if isReviewing {
                TextEditor(text: $reviewText)
                    .font(.system(size: 15))
                    .tracking(-0.23)
                    .lineSpacing(5)
                    .tint(theme.accent)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .overlay(alignment: .topLeading) {
                        if reviewText.isEmpty {
                            Text("Add dream description...")
                                .font(.system(size: 15))
                                .tracking(-0.23)
                                .foregroundStyle(.secondary)
                                .padding(.top, 24)
                                .padding(.leading, 25)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        if speechService.transcribedText.isEmpty {
                            Text("Live Captions will appear here...")
                                .font(.system(size: 15))
                                .tracking(-0.23)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        } else {
                            liveCaptionsText
                                .font(.system(size: 15))
                                .tracking(-0.23)
                                .lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        Color.clear.frame(height: 1).id("captionsBottom")
                    }
                    .scrollIndicators(.hidden)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .onChange(of: speechService.transcribedText) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("captionsBottom", anchor: .bottom)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            if isRecording || isReviewing {
                LiveWaveformView(
                    isAnimating: isRecording && !isPaused,
                    isReviewing: isReviewing,
                    isVisible: isVisible,
                    audioRecorder: audioRecorder
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

                timerRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Timer Row

    private var timerRow: some View {
        Group {
            if isRecording {
                timerText
            } else if isReviewing {
                LiveReviewTimerView(audioRecorder: audioRecorder, totalSeconds: totalRecordingSeconds)
            }
        }
    }

    // MARK: - Mode Switch Pill

    private var modeSwitchPill: some View {
        Button {
            if viewModel.mode == .voice {
                viewModel.mode = .text
                isTextFocused = true
            } else {
                isTextFocused = false
                viewModel.mode = .voice
            }
        } label: {
            HStack(spacing: 6) {
                Image(viewModel.mode == .voice ? "TextModeIcon" : "VoiceModeIcon")
                    .renderingMode(.template)
                    .foregroundStyle(theme.accent)
                Text(viewModel.mode == .voice ? "Text Mode" : "Voice Mode")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.7), lineWidth: 1)
            )
            .reveriGlass(.capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timer Text

    private var timerText: some View {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60

        return Text(String(format: "%02d:%02d:%02d", h, m, s))
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondary)
    }

    // MARK: - Live Captions Text

    private var liveCaptionsText: Text {
        let gradient = LinearGradient(
            colors: [.primary, theme.accent],
            startPoint: .leading,
            endPoint: .trailing
        )

        if speechService.latestText.isEmpty {
            return Text(speechService.stableText)
                .foregroundStyle(.primary)
        }

        return Text("\(Text(speechService.stableText).foregroundStyle(.primary))\(Text(speechService.latestText).foregroundStyle(gradient))")
    }

    // MARK: - Recording

    private func requestMicAndRecord() {
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                guard granted else { return }
                let audioStream = audioRecorder.startRecording()
                let locale = Locale(identifier: selectedLocaleId)
                speechService.startTranscription(locale: locale, audioStream: audioStream)
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    isRecording = true
                }
                isPaused = false
                elapsedSeconds = 0
                startTimer()
                liveActivityManager?.startRecording()
            }
        }
    }

    private func handleStop() {
        let url = audioRecorder.stopRecording()
        speechService.stopTranscription()
        timerTask?.cancel()
        timerTask = nil
        liveActivityManager?.end()

        guard elapsedSeconds > 1 else {
            audioRecorder.deleteRecording()
            speechService.resetTranscription()
            elapsedSeconds = 0
            return
        }

        let transcript = speechService.transcribedText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if url != nil {
            reviewText = transcript
            totalRecordingSeconds = elapsedSeconds
            speechService.resetTranscription()
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                isReviewing = true
            }
        } else if !transcript.isEmpty {
            viewModel.dreamText = transcript
            viewModel.mode = .text
            speechService.resetTranscription()
            elapsedSeconds = 0
            totalRecordingSeconds = 0
        } else {
            speechService.resetTranscription()
            elapsedSeconds = 0
        }
    }

    private func handleDelete() {
        speechService.resetTranscription()
        reviewText = ""
        elapsedSeconds = 0
        totalRecordingSeconds = 0
    }

    private func handleSaveAudio() {
        audioRecorder.stopPlayback()
        guard let url = audioRecorder.recordedFileURL else { return }
        let relativePath = url.lastPathComponent
        let transcript = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.saveAudioDream(audioPath: relativePath, transcript: transcript, context: modelContext)

        reviewText = ""
        elapsedSeconds = 0
        totalRecordingSeconds = 0
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            isReviewing = false
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                if !isPaused {
                    elapsedSeconds += 1
                }
            }
        }
    }
}

// MARK: - LiveWaveformView (isolates audioRecorder.currentLevel observation)

private struct LiveWaveformView: View {
    let isAnimating: Bool
    let isReviewing: Bool
    var isVisible: Bool = true
    var audioRecorder: AudioRecorder

    var body: some View {
        AudioWaveformView(
            isAnimating: isAnimating,
            level: isAnimating ? audioRecorder.currentLevel : 0,
            isPlayingBack: audioRecorder.isPlaying,
            playbackProgress: isReviewing && audioRecorder.playbackDuration > 0
                ? CGFloat(audioRecorder.playbackCurrentTime / audioRecorder.playbackDuration)
                : 0,
            playbackDuration: audioRecorder.playbackDuration,
            isVisible: isVisible
        )
    }
}

// MARK: - LiveReviewTimerView (isolates playbackCurrentTime observation)

private struct LiveReviewTimerView: View {
    var audioRecorder: AudioRecorder
    let totalSeconds: Int

    var body: some View {
        HStack {
            Text(formatTime(Int(audioRecorder.playbackCurrentTime)))
            Spacer()
            Text(formatTime(totalSeconds))
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.secondary)
    }

    private func formatTime(_ s: Int) -> String {
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return String(format: "%02d:%02d:%02d", h, m, sec)
    }
}
