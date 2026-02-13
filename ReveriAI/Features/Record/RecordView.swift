import SwiftUI
import SwiftData
import AVFoundation

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
    var audioRecorder: AudioRecorder
    var speechService: SpeechRecognitionService

    var onDreamSaved: ((Dream) -> Void)?

    init(
        isRecording: Binding<Bool>,
        isPaused: Binding<Bool>,
        isReviewing: Binding<Bool>,
        audioRecorder: AudioRecorder,
        speechService: SpeechRecognitionService,
        onDreamSaved: ((Dream) -> Void)? = nil
    ) {
        self._isRecording = isRecording
        self._isPaused = isPaused
        self._isReviewing = isReviewing
        self.audioRecorder = audioRecorder
        self.speechService = speechService
        self.onDreamSaved = onDreamSaved
    }

    private let cloudHeight: CGFloat = 159
    private let baseHeaderHeight: CGFloat = 255

    private var headerRatio: CGFloat {
        isTextFocused ? 0.38 : 1.0
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
                    .animation(.easeOut(duration: 0.3), value: isTextFocused)

                // Layer 2: Header gradient background (animated)
                headerGradientBackground
                    .animation(.easeOut(duration: 0.3), value: isTextFocused)

                // Layer 3: Title + icon (shifts up slightly when keyboard appears)
                headerTitle
                    .offset(y: isTextFocused ? -25 : 0)
                    .animation(.easeOut(duration: 0.3), value: isTextFocused)

                // Layer 4: Clouds + pill (animated, on top of title)
                cloudLayer
                    .animation(.easeOut(duration: 0.3), value: isTextFocused)
            }
            .ignoresSafeArea(edges: .top)

            // "How did it feel?" card
            if viewModel.showHowDidItFeel {
                HowDidItFeelCard(
                    onTap: {
                        if let dream = viewModel.savedDream {
                            onDreamSaved?(dream)
                        }
                        viewModel.dismissHowDidItFeel()
                    },
                    onDismiss: {
                        viewModel.dismissHowDidItFeel()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 80)
            }
        }
        .toast(isPresented: $viewModel.showToast, message: "Dream saved")
        .animation(.spring(duration: 0.4), value: viewModel.showHowDidItFeel)
        .onChange(of: isRecording) { _, newValue in
            if !newValue { handleStop() }
        }
        .onChange(of: isPaused) { _, paused in
            if isRecording {
                if paused {
                    audioRecorder.pauseRecording()
                } else {
                    audioRecorder.resumeRecording()
                }
            }
        }
        .onChange(of: isReviewing) { _, newValue in
            if !newValue {
                handleDelete()
            }
        }
    }

    // MARK: - Header Gradient Background (animated)

    private var headerGradientBackground: some View {
        DreamHeader()
            .frame(height: headerHeight + cloudOverhang)
            .clipped()
    }

    // MARK: - Header Title (static — never moves)

    private var headerTitle: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("What did")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(.white)
                Text("you dream")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(.white)
                Text("about...?")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(theme.accent)
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
    }

    // MARK: - Cloud Layer + Pill (animated, on top of title)

    private var cloudLayer: some View {
        Color.clear
            .frame(height: headerHeight)
            .overlay(alignment: .bottom) {
                CloudSeparator()
                    .frame(height: cloudHeight)
                    .offset(y: cloudOverhang)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                if isRecording {
                    timerText
                        .padding(.leading, 20)
                        .offset(y: cloudOverhang + 30)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if isReviewing {
                    reviewTimerText
                        .padding(.leading, 20)
                        .offset(y: cloudOverhang + 30)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if viewModel.mode == .text && viewModel.canSave {
                    SaveDreamButton {
                        viewModel.saveDream(context: modelContext)
                        isTextFocused = false
                    }
                    .padding(.leading, 16)
                    .offset(y: cloudOverhang + 30)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isReviewing {
                    SaveDreamButton {
                        handleSaveAudio()
                    }
                    .padding(.trailing, 16)
                    .offset(y: cloudOverhang + 30)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if !isRecording {
                    modeSwitchPill
                        .padding(.trailing, 16)
                        .offset(y: cloudOverhang + 30)
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
                .padding(.top, 36)
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
        let currentSeconds = Int(audioRecorder.playbackCurrentTime)
        let ch = currentSeconds / 3600
        let cm = (currentSeconds % 3600) / 60
        let cs = currentSeconds % 60

        let th = totalRecordingSeconds / 3600
        let tm = (totalRecordingSeconds % 3600) / 60
        let ts = totalRecordingSeconds % 60

        return Text(String(format: "%02d:%02d:%02d — %02d:%02d:%02d", ch, cm, cs, th, tm, ts))
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.black.opacity(0.3))
    }

    // MARK: - Voice Placeholder

    private var voicePlaceholder: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isRecording || isReviewing {
                LiveWaveformView(
                    isAnimating: isRecording && !isPaused,
                    audioRecorder: audioRecorder
                )
                .padding(.bottom, 24)
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

            // Live Captions
            ScrollView {
                if speechService.transcribedText.isEmpty {
                    Text("Live Captions will appear here")
                        .font(.system(size: 15))
                        .tracking(-0.23)
                        .foregroundStyle(.black.opacity(0.3))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                } else {
                    liveCaptionsText
                        .font(.system(size: 15))
                        .tracking(-0.23)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
            .padding(.bottom, 100)
        }
        .padding(.horizontal, 20)
        .padding(.top, 44)
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
            }
        }
    }

    private func handleStop() {
        let url = audioRecorder.stopRecording()
        speechService.stopTranscription()
        timerTask?.cancel()
        timerTask = nil

        guard elapsedSeconds > 1 else {
            // Too short — auto-discard
            audioRecorder.deleteRecording()
            speechService.resetTranscription()
            elapsedSeconds = 0
            return
        }

        let transcript = speechService.transcribedText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !transcript.isEmpty {
            // Transfer transcript to text mode for editing
            viewModel.dreamText = transcript
            viewModel.mode = .text
            speechService.resetTranscription()
            audioRecorder.deleteRecording()
            elapsedSeconds = 0
            totalRecordingSeconds = 0
        } else if url != nil {
            // No transcript — fall back to audio review
            totalRecordingSeconds = elapsedSeconds
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                isReviewing = true
            }
        } else {
            speechService.resetTranscription()
            elapsedSeconds = 0
        }
    }

    private func handleDelete() {
        speechService.resetTranscription()
        elapsedSeconds = 0
        totalRecordingSeconds = 0
    }

    private func handleSaveAudio() {
        audioRecorder.stopPlayback()
        guard let url = audioRecorder.recordedFileURL else { return }
        let relativePath = url.lastPathComponent
        let transcript = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.saveAudioDream(audioPath: relativePath, transcript: transcript, context: modelContext)
        speechService.resetTranscription()

        // Reset review state
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
private struct LiveWaveformView: View {
    let isAnimating: Bool
    var audioRecorder: AudioRecorder

    var body: some View {
        AudioWaveformView(
            isAnimating: isAnimating,
            level: isAnimating ? audioRecorder.currentLevel : 0
        )
    }
}
