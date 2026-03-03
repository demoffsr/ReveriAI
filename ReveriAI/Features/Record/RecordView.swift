import SwiftUI
import SwiftData
import AVFoundation
import os

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
    @State private var waveformState = WaveformState()
    @State private var reviewText: String = ""
    @State private var headerContentVisible: Bool = true
    var audioRecorder: AudioRecorder
    var speechService: SpeechRecognitionService
    var isVisible: Bool = true
    var liveActivityManager: LiveActivityManager?
    var headerBackgroundStorage: HeaderBackgroundStorage
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
        headerBackgroundStorage: HeaderBackgroundStorage,
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
        self.headerBackgroundStorage = headerBackgroundStorage
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

    /// How far the shield slides up in text mode
    private var shieldOffset: CGFloat {
        isTextFocused ? -(baseHeaderHeight - baseHeaderHeight * 0.22) : 0
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                // Layer 0: Light background
                theme.cloudFront
                    .ignoresSafeArea()

                // Layer 1: Header background (fixed size — cached as Metal texture)
                DreamHeader(headerBackgroundStorage: headerBackgroundStorage)
                    .frame(height: baseHeaderHeight + cloudOverhang - 8)
                    .drawingGroup(opaque: true)
                    .opacity(headerContentVisible ? 1 : 0)

                // Layer 2: Title + icon
                headerTitle
                    .offset(y: isTextFocused ? -25 : 0)

                // Layer 3: Shield — CloudSeparator + pills + white content (slides up)
                contentShield
                    .offset(y: shieldOffset)

                // Layer 4: Closing cloud — ON TOP of everything, slides down to cover header
                closingClouds
                    .allowsHitTesting(false)
            }
            .animation(.spring(duration: 0.35, bounce: 0.0), value: isTextFocused)
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            Logger(subsystem: "com.reveri", category: "Launch").info("⏱ RecordView appeared")
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
                    liveActivityManager?.startLevelSampling(audioRecorder: audioRecorder)
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

    // MARK: - Closing Clouds (slides down from top to cover header)

    /// Closing cloud height: sized so wavy bottom aligns with shield's CloudSeparator bottom
    private var closingCloudHeight: CGFloat {
        // Shield CloudSeparator bottom when focused:
        // (baseHeaderHeight - cloudOverhang) + shieldOffset + cloudHeight
        let shieldTopFocused = (baseHeaderHeight - cloudOverhang) + (-(baseHeaderHeight - baseHeaderHeight * 0.22))
        return shieldTopFocused + cloudHeight
    }

    private var closingClouds: some View {
        VStack(spacing: 0) {
            theme.cloudFront // thin solid fill above cloud bumps
            CloudClosedShape()
                .fill(theme.cloudFront)
                .frame(height: cloudHeight)
        }
        .frame(height: closingCloudHeight)
        .offset(y: isTextFocused ? 0 : -closingCloudHeight)
    }

    // MARK: - Header Title

    private var headerTitle: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "record.describe", defaultValue: "Describe"))
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(.white)
                Text("\(Text(String(localized: "record.your", defaultValue: "your ")).foregroundStyle(.white))\(Text(String(localized: "record.dream", defaultValue: "dream")).foregroundStyle(theme.accent))")
                    .font(.system(size: 36, weight: .heavy))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.top, 60)
            .padding(.leading, 20)
            .allowsHitTesting(false)

            Spacer(minLength: 0)
                .allowsHitTesting(false)

            CelestialIcon()
                .padding(.top, 50)
                .padding(.trailing, 12)
        }
        .opacity(headerContentVisible ? 1 : 0)
    }

    // MARK: - Content Shield (CloudSeparator + pills + content — one sliding unit)

    private var contentShield: some View {
        VStack(spacing: 0) {
            // Cloud separator — bumps stick up into header area
            CloudSeparator()
                .frame(height: cloudHeight)
                .allowsHitTesting(false)

            // Pills (timer / save / mode switch)
            HStack {
                if isRecording {
                    timerText
                        .padding(.leading, 20)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if isReviewing {
                    reviewTimerText
                        .padding(.leading, 20)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if viewModel.mode == .text && viewModel.canSave {
                    SaveDreamButton {
                        viewModel.saveDream(context: modelContext)
                        isTextFocused = false
                    }
                    .padding(.leading, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                Spacer(minLength: 0)

                if isReviewing {
                    SaveDreamButton {
                        handleSaveAudio()
                    }
                    .padding(.trailing, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if !isRecording {
                    modeSwitchPill
                        .padding(.trailing, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.top, 8)
            .animation(.easeOut(duration: 0.25), value: viewModel.canSave)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: isRecording)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: isReviewing)

            // Content
            if viewModel.mode == .text {
                TextModeView(
                    text: $viewModel.dreamText,
                    isFocused: $isTextFocused
                )
                .padding(.top, isTextFocused ? 16 : 24)
            } else {
                voicePlaceholder
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .background(alignment: .top) {
            // White background starts where cloud bumps end (solid fill area)
            theme.cloudFront
                .padding(.top, cloudHeight * 0.5)
        }
        // Position so CloudSeparator overlaps bottom of header
        // Top of cloud bumps at: baseHeaderHeight - cloudOverhang = 175.5pt
        .padding(.top, baseHeaderHeight - cloudOverhang)
    }

    // MARK: - Mode Switch Pill

    private var modeSwitchPill: some View {
        Button {
            if viewModel.mode == .voice {
                viewModel.mode = .text
                isTextFocused = true
                AnalyticsService.track(.modeSwitched, metadata: ["mode": "text"])
            } else {
                isTextFocused = false
                viewModel.mode = .voice
                AnalyticsService.track(.modeSwitched, metadata: ["mode": "voice"])
            }
        } label: {
            HStack(spacing: 6) {
                Image(viewModel.mode == .voice ? "TextModeIcon" : "VoiceModeIcon")
                    .renderingMode(.template)
                    .foregroundStyle(theme.accent)
                Text(viewModel.mode == .voice ? String(localized: "record.textMode", defaultValue: "Text Mode") : String(localized: "record.voiceMode", defaultValue: "Voice Mode"))
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
                    audioRecorder: audioRecorder,
                    waveformState: waveformState
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

                        Text(String(localized: "record.startRecording", defaultValue: "Start Recording"))
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
                            Text(String(localized: "record.addDreamDescription", defaultValue: "Add dream description..."))
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
        .padding(.top, 16)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: "record.done", defaultValue: "Done")) {
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
                waveformState.reset()
                DreamAIService.warmUp()
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
                liveActivityManager?.startLevelSampling(audioRecorder: audioRecorder)
            }
        }
    }

    private func handleStop() {
        let url = audioRecorder.stopRecording()
        speechService.stopTranscription()
        timerTask?.cancel()
        timerTask = nil
        liveActivityManager?.stopLevelSampling()
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
                    liveActivityManager?.updateLevels(elapsedSeconds: elapsedSeconds)
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
    var waveformState: WaveformState

    var body: some View {
        AudioWaveformView(
            isAnimating: isAnimating,
            level: isAnimating ? audioRecorder.currentLevel : 0,
            isPlayingBack: audioRecorder.isPlaying,
            playbackProgress: isReviewing && audioRecorder.playbackDuration > 0
                ? CGFloat(audioRecorder.playbackCurrentTime / audioRecorder.playbackDuration)
                : 0,
            playbackDuration: audioRecorder.playbackDuration,
            isVisible: isVisible,
            waveformState: waveformState
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
                    Text(String(localized: "record.liveCaptions", defaultValue: "Live Captions will appear here"))
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
