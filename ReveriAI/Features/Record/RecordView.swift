import SwiftUI
import SwiftData
import AVFoundation

struct RecordView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @AppStorage("speechRecognitionLocale") private var selectedLocaleId: String = SpeechLocale.defaultLocale.identifier
    @State private var viewModel = RecordViewModel()
    @FocusState private var isTextFocused: Bool
    @FocusState private var isReviewTextFocused: Bool

    @Binding var isRecording: Bool
    @Binding var isPaused: Bool
    @Binding var isReviewing: Bool
    @State private var elapsedSeconds: Int = 0
    @State private var totalRecordingSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var reviewText: String = ""
    @State private var headerContentVisible: Bool = true
    var audioRecorder: AudioRecorder
    var speechService: SpeechRecognitionService
    var isVisible: Bool = true
    var liveActivityManager: LiveActivityManager?
    @Binding var startRecordingTrigger: Bool
    @Binding var startTextModeTrigger: Bool
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
        startRecordingTrigger: Binding<Bool> = .constant(false),
        startTextModeTrigger: Binding<Bool> = .constant(false),
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
        self._startRecordingTrigger = startRecordingTrigger
        self._startTextModeTrigger = startTextModeTrigger
        self.onDreamSaved = onDreamSaved
        self.onShowHowDidItFeel = onShowHowDidItFeel
    }

    private let cloudHeight: CGFloat = 89
    private let baseHeaderHeight: CGFloat = 220

    private var headerRatio: CGFloat {
        isTextFocused ? 0.22 : 1.0
    }

    private var headerHeight: CGFloat {
        baseHeaderHeight * headerRatio
    }

    /// How far clouds extend below the header's bottom edge
    private var cloudOverhang: CGFloat {
        cloudHeight * 0.5
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main layered layout
            ZStack(alignment: .top) {
                // Layer 0: Light background fills entire screen
                theme.cloudFront
                    .ignoresSafeArea()

                // Layer 1: Content (below header + cloud zone)
                contentArea
                    .animation(.spring(duration: 0.45, bounce: 0.0), value: isTextFocused)

                // Layer 2: Header gradient background (animated)
                headerGradientBackground
                    .animation(.spring(duration: 0.45, bounce: 0.0), value: isTextFocused)

                // Layer 3: Title + icon (shifts up slightly when keyboard appears)
                headerTitle
                    .offset(y: isTextFocused ? -25 : 0)
                    .animation(.spring(duration: 0.45, bounce: 0.0), value: isTextFocused)

                // Layer 4: Clouds + pill (animated, on top of title)
                cloudLayer
                    .animation(.spring(duration: 0.45, bounce: 0.0), value: isTextFocused)
            }
            .ignoresSafeArea(edges: .top)
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
        .onChange(of: isTextFocused) { _, focused in
            if focused {
                withAnimation(.easeOut(duration: 0.1)) {
                    headerContentVisible = false
                }
            } else {
                withAnimation(.easeOut(duration: 0.1)) {
                    headerContentVisible = true
                }
            }
        }
        .onChange(of: selectedLocaleId, initial: true) { _, newValue in
            viewModel.speechLocaleRaw = newValue
        }
        .onChange(of: startRecordingTrigger) { _, _ in
            guard !isRecording && !isReviewing else { return }
            requestMicAndRecord()
        }
        .onChange(of: startTextModeTrigger) { _, _ in
            guard !isRecording && !isReviewing else { return }
            viewModel.mode = .text
            isTextFocused = true
        }
    }

    // MARK: - Header Gradient Background (animated)

    private var headerGradientBackground: some View {
        DreamHeader()
            .frame(height: headerHeight + cloudOverhang - 8)
            .clipped()
            .opacity(headerContentVisible ? 1 : 0)
    }

    // MARK: - Closing Clouds (inverted clouds descend from above)

    private var closingClouds: some View {
        VStack(spacing: 0) {
            // Solid fill covers header above cloud bumps
            theme.cloudFront
            // Cloud shape at natural proportions (matches bottom clouds)
            CloudClosedShape()
                .fill(theme.cloudFront)
                .frame(height: cloudHeight)
        }
        .frame(height: headerHeight + cloudOverhang)
        .offset(y: isTextFocused ? 0 : -(baseHeaderHeight + cloudOverhang))
    }

    // MARK: - Header Title (static — never moves)

    private var headerTitle: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Describe")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(.white)
                Text("\(Text("your ").foregroundStyle(.white))\(Text("dream").foregroundStyle(theme.accent))")
                    .font(.system(size: 36, weight: .heavy))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.top, 60)
            .padding(.leading, 20)

            Spacer(minLength: 0)

            CelestialIcon()
                .padding(.top, 50)
                .padding(.trailing, 12)
        }
        .allowsHitTesting(false)
        .opacity(headerContentVisible ? 1 : 0)
    }

    // MARK: - Cloud Layer + Pill (animated, on top of title)

    private var cloudLayer: some View {
        Color.clear
            .frame(height: headerHeight)
            .overlay(alignment: .bottom) {
                CloudSeparator()
                    .frame(height: cloudHeight)
                    .offset(y: cloudOverhang)
                    .opacity(headerContentVisible ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                closingClouds
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                if isRecording {
                    timerText
                        .padding(.leading, 20)
                        .offset(y: cloudOverhang + 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if isReviewing {
                    reviewTimerText
                        .padding(.leading, 20)
                        .offset(y: cloudOverhang + 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if viewModel.mode == .text && viewModel.canSave {
                    SaveDreamButton {
                        viewModel.saveDream(context: modelContext)
                        isTextFocused = false
                    }
                    .padding(.leading, 16)
                    .offset(y: cloudOverhang + 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isReviewing {
                    SaveDreamButton {
                        handleSaveAudio()
                    }
                    .padding(.trailing, 16)
                    .offset(y: cloudOverhang + 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if !isRecording {
                    modeSwitchPill
                        .padding(.trailing, 16)
                        .offset(y: cloudOverhang + 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.easeOut(duration: 0.25), value: viewModel.canSave)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: isRecording)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: isReviewing)
    }

    // MARK: - Content

    private var contentArea: some View {
        VStack(spacing: 0) {
            // Reserve space for header + cloud overhang
            Color.clear
                .frame(height: headerHeight + cloudOverhang)

            // Text editor or voice placeholder
            if viewModel.mode == .text {
                TextModeView(
                    text: $viewModel.dreamText,
                    isFocused: $isTextFocused
                )
                .padding(.top, isTextFocused ? 16 : 36)
            } else {
                voicePlaceholder
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
            .glassEffect(.clear.interactive(), in: .capsule)
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
            .foregroundStyle(.black.opacity(0.3))
    }

    // MARK: - Review Timer Text

    private var reviewTimerText: some View {
        LiveReviewTimerView(
            audioRecorder: audioRecorder,
            totalRecordingSeconds: totalRecordingSeconds
        )
    }

    // MARK: - Voice Placeholder

    private var voicePlaceholder: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isRecording || isReviewing {
                LiveWaveformView(
                    isAnimating: isRecording && !isPaused,
                    isReviewing: isReviewing,
                    isVisible: isVisible,
                    audioRecorder: audioRecorder
                )
                .padding(.bottom, 8)
            } else {
                // Start Recording button
                Button {
                    requestMicAndRecord()
                } label: {
                    HStack(spacing: 8) {
                        // Orange circle with glass effect + mic icon
                        ZStack {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 36, height: 36)
                            Image("VoiceModeButtonIcon")
                                .renderingMode(.original)
                        }
                        .frame(width: 40, height: 40)
                        .glassEffect(.regular, in: .circle)

                        Text("Start Recording")
                            .font(.system(size: 15, weight: .medium))
                            .tracking(-0.23)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)

            }

            // Captions: editable in review mode, read-only during recording
            if isReviewing {
                TextEditor(text: $reviewText)
                    .focused($isReviewTextFocused)
                    .font(.system(size: 15))
                    .tracking(-0.23)
                    .lineSpacing(5)
                    .tint(theme.accent)
                    .scrollContentBackground(.hidden)
                    .padding(.bottom, 100)
                    .overlay(alignment: .topLeading) {
                        if reviewText.isEmpty {
                            Text("Add dream description...")
                                .font(.system(size: 15))
                                .tracking(-0.23)
                                .foregroundStyle(.black.opacity(0.3))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                LiveCaptionsView(speechService: speechService)
                    .padding(.bottom, 100)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTextFocused = false
                    isReviewTextFocused = false
                }
                .fontWeight(.medium)
            }
        }
    }

    // MARK: - Recording

    private func requestMicAndRecord() {
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                guard granted else { return }
                let audioStream = audioRecorder.startRecording()
                let locale = Locale(identifier: selectedLocaleId)
                speechService.startTranscription(locale: locale, audioStream: audioStream)
                HapticService.impact(.medium)
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
            // Too short — auto-discard
            audioRecorder.deleteRecording()
            speechService.resetTranscription()
            elapsedSeconds = 0
            return
        }

        let transcript = speechService.transcribedText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if url != nil {
            // Enter review mode with editable transcript
            reviewText = transcript
            totalRecordingSeconds = elapsedSeconds
            speechService.resetTranscription()
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                isReviewing = true
            }
        } else if !transcript.isEmpty {
            // No audio file but have transcript — fall back to text mode
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

        // Reset review state
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

/// Wrapper that observes `audioRecorder.currentLevel` in its own body,
/// preventing RecordView from re-evaluating ~43 times/sec.
/// Also isolates playback progress observation during review.
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

private struct LiveReviewTimerView: View {
    let audioRecorder: AudioRecorder
    let totalRecordingSeconds: Int

    var body: some View {
        let currentSeconds = Int(audioRecorder.playbackCurrentTime)
        let ch = currentSeconds / 3600
        let cm = (currentSeconds % 3600) / 60
        let cs = currentSeconds % 60

        let th = totalRecordingSeconds / 3600
        let tm = (totalRecordingSeconds % 3600) / 60
        let ts = totalRecordingSeconds % 60

        Text(String(format: "%02d:%02d:%02d — %02d:%02d:%02d", ch, cm, cs, th, tm, ts))
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.black.opacity(0.3))
    }
}

// MARK: - LiveCaptionsView (isolates speechService observation)

private struct LiveCaptionsView: View {
    var speechService: SpeechRecognitionService
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if speechService.transcribedText.isEmpty {
                    Text("Live Captions will appear here")
                        .font(.system(size: 15))
                        .tracking(-0.23)
                        .foregroundStyle(.black.opacity(0.3))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                } else {
                    captionsText
                        .font(.system(size: 15))
                        .tracking(-0.23)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                Color.clear.frame(height: 1).id("captionsBottom")
            }
            .scrollIndicators(.hidden)
            .onChange(of: speechService.transcribedText) {
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo("captionsBottom", anchor: .bottom)
                }
            }
        }
    }

    private var captionsText: Text {
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
}
