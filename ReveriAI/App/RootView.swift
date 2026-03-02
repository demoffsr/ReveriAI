import SwiftUI
import SwiftData
import os

private let launchLog = Logger(subsystem: "com.reveri", category: "Launch")

struct RootView: View {
    @State private var selectedTab: AppTab = .record
    @State private var savedDreamForEmotion: Dream?
    @State private var isRecording = false
    @State private var isPaused = false
    @State private var isReviewing = false
    @State private var audioRecorder = AudioRecorder()
    @State private var speechService = SpeechRecognitionService()
    @State private var selectedEmotionFilter: DreamEmotion?
    @State private var emotionOrder: [DreamEmotion] = DreamEmotion.allCases
    @State private var showHowDidItFeel = false
    @State private var showEmotionGrid = false
    @State private var showDreamSaved = false
    @State private var pendingEmotions: Set<DreamEmotion> = []
@State private var dismissTask: Task<Void, Never>?
    @State private var isInDetailDreamTab = false
    @State private var detailDreamHasImage = false
    @State private var detailDreamIsGenerating = false
    @State private var detailDreamGenerateTrigger = false
    @State private var detailDreamState = DetailDreamState()
    @State private var liveActivityManager = LiveActivityManager()
    @State private var notificationService = NotificationService()
    @State private var dreamReminderManager = DreamReminderManager()
    @State private var avatarStorage = AvatarStorage()
    @State private var headerBackgroundStorage = HeaderBackgroundStorage()
    @State private var startRecordingTrigger = false
    @State private var audioPlaybackService = AudioPlaybackService()
    @State private var startTextModeTrigger = false
    @State private var journalMounted = false
    @State private var isJournalSearchActive = false
    @State private var tabBarSearchHidden = false
    @State private var isInProfile = false
    @State private var tabBarShowTask: Task<Void, Never>?
    @State private var showDeepLinkRecordConfirmation = false
    @State private var launchComplete = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    private var recordTab: some View {
        RecordView(
            isRecording: $isRecording,
            isPaused: $isPaused,
            isReviewing: $isReviewing,
            audioRecorder: audioRecorder,
            speechService: speechService,
            isVisible: selectedTab == .record,
            liveActivityManager: liveActivityManager,
            headerBackgroundStorage: headerBackgroundStorage,
            startRecordingTrigger: $startRecordingTrigger,
            startTextModeTrigger: $startTextModeTrigger,
            onDreamSaved: { dream in
                savedDreamForEmotion = dream
                dreamReminderManager.end()
            },
            onShowHowDidItFeel: {
                dismissTask?.cancel()
                showDreamSaved = false
                withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                    showHowDidItFeel = true
                }
            }
        )
        .zIndex(selectedTab == .record ? 1 : 0)
        .allowsHitTesting(selectedTab == .record)
    }

    private var journalTab: some View {
        JournalView(
            selectedEmotion: $selectedEmotionFilter,
            emotionOrder: $emotionOrder,
            isInDetailDreamTab: $isInDetailDreamTab,
            detailDreamHasImage: $detailDreamHasImage,
            detailDreamIsGenerating: $detailDreamIsGenerating,
            detailDreamGenerateTrigger: $detailDreamGenerateTrigger,
            detailDreamState: detailDreamState,
            notificationService: notificationService,
            dreamReminderManager: dreamReminderManager,
            avatarStorage: avatarStorage,
            headerBackgroundStorage: headerBackgroundStorage,
            isSearchActive: $isJournalSearchActive,
            isInProfile: $isInProfile
        )
        .zIndex(selectedTab == .journal ? 1 : 0)
        .allowsHitTesting(selectedTab == .journal)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                recordTab
                if journalMounted {
                    journalTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Dismiss overlay (tap outside grid)
            if showEmotionGrid && selectedTab == .record {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.4)) {
                            showEmotionGrid = false
                        }
                    }
            }

            // Emotion picker grid (above tab bar)
            if showEmotionGrid && selectedTab == .record {
                EmotionPickerGrid(selectedEmotions: $pendingEmotions)
                    .padding(.bottom, 100)
            }

            // How did it feel card (floating above tab bar)
            if showHowDidItFeel && !showEmotionGrid && selectedTab == .record {
                HowDidItFeelCard(
                    onTap: {
                        withAnimation(.spring(duration: 0.4)) {
                            showEmotionGrid = true
                        }
                    },
                    onDismiss: {
                        if !pendingEmotions.isEmpty {
                            saveFeelings()
                        } else {
                            dismissWithSaved()
                        }
                    },
                    showSavedState: showDreamSaved
                )
                .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                .padding(.bottom, 100)
            }

            // Custom tab bar (isolated audio state observation)
            TabBarWithAudioState(
                selectedTab: $selectedTab,
                emotionFilter: selectedEmotionFilter,
                isRecording: isRecording,
                isPaused: isPaused,
                isReviewing: isReviewing,
                isSavingFeelings: showEmotionGrid,
                canSaveFeelings: !pendingEmotions.isEmpty,
                onStop: {
                    AnalyticsService.track(.recordStopped)
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        isRecording = false
                        isPaused = false
                    }
                },
                onTogglePause: {
                    if isPaused {
                        AnalyticsService.track(.recordResumed)
                    } else {
                        AnalyticsService.track(.recordPaused)
                    }
                    isPaused.toggle()
                },
                onTogglePreview: {
                    AnalyticsService.track(.audioPlaybackStarted)
                    audioPlaybackService.stop()
                    audioRecorder.togglePlayback()
                },
                onDelete: {
                    AnalyticsService.track(.recordDeleted)
                    audioRecorder.deleteRecording()
                    speechService.resetTranscription()
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        isReviewing = false
                    }
                },
                onSkipBack: {
                    AnalyticsService.track(.audioPlaybackSkip, metadata: ["direction": "back"])
                    audioRecorder.skipBackward()
                },
                onSkipForward: {
                    AnalyticsService.track(.audioPlaybackSkip, metadata: ["direction": "forward"])
                    audioRecorder.skipForward()
                },
                onSaveFeelings: {
                    saveFeelings()
                },
                isInDetailDreamTab: isInDetailDreamTab,
                hasGeneratedImage: detailDreamHasImage,
                isGeneratingImage: detailDreamIsGenerating,
                onGenerateImage: {
                    detailDreamGenerateTrigger.toggle()
                },
                detailState: detailDreamState,
                audioRecorder: audioRecorder,  // Reference only — NO property read in RootView
                audioPlaybackService: audioPlaybackService
            )
            .opacity(tabBarSearchHidden || isInProfile ? 0 : 1)
            .animation(nil, value: tabBarSearchHidden)
            .allowsHitTesting(!isInProfile)
        }
        .environment(\.audioPlayback, audioPlaybackService)
        .ignoresSafeArea(.keyboard)
        .animation(.spring(duration: 0.4), value: showEmotionGrid)
        .onChange(of: isJournalSearchActive) { _, active in
            tabBarShowTask?.cancel()
            if active && selectedTab == .journal {
                tabBarSearchHidden = true
            } else {
                tabBarShowTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(80))
                    guard !Task.isCancelled else { return }
                    tabBarSearchHidden = false
                }
            }
        }
        .onChange(of: isRecording) { _, recording in
            if recording {
                AnalyticsService.track(.recordStarted)
                audioPlaybackService.stop()
                dreamReminderManager.end()
                showEmotionGrid = false
                showHowDidItFeel = false
                showDreamSaved = false
                pendingEmotions = []
                dismissTask?.cancel()
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            AnalyticsService.track(.tabSwitched, metadata: ["tab": newTab.rawValue])
            // Mount JournalView immediately on first switch
            if newTab == .journal && !journalMounted {
                journalMounted = true
            }
        }
        .task {
            launchLog.info("⏱ RootView .task started")
            AnalyticsService.setup()

            // Load deferred images (not in init to keep launch fast)
            avatarStorage.loadFromDisk()
            headerBackgroundStorage.loadFromDisk()

            // Defer dream reminder — not startup critical
            try? await Task.sleep(for: .seconds(2))
            launchLog.info("⏱ DreamReminder starting")
            await dreamReminderManager.reconnect()
            if !isRecording && !isReviewing {
                dreamReminderManager.validateAndAutoStart()
            }
            launchLog.info("⏱ DreamReminder setup done")
            launchComplete = true
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && launchComplete {
                AnalyticsService.track(.appForeground)
                Task {
                    await dreamReminderManager.reconnect()
                    if !isRecording && !isReviewing {
                        dreamReminderManager.validateAndAutoStart()
                    }
                }
            }
            if phase == .background {
                AnalyticsService.track(.appBackground)
                Task { await AnalyticsService.flush() }
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .confirmationDialog(
            "Начать запись сна?",
            isPresented: $showDeepLinkRecordConfirmation,
            titleVisibility: .visible
        ) {
            Button("Начать запись") {
                startRecordingTrigger.toggle()
            }
            Button("Отмена", role: .cancel) {}
        }
        .onReceive(NotificationCenter.default.publisher(for: .dreamReminderRecord)) { _ in
            selectedTab = .record
            startRecordingTrigger.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dreamReminderWrite)) { _ in
            selectedTab = .record
            startTextModeTrigger.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dreamReminderStartActivity)) { _ in
            if !dreamReminderManager.isActive {
                dreamReminderManager.start()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("startDreamRecordingFromLA"))) { _ in
            guard !isRecording && !isReviewing else { return }
            dreamReminderManager.end()
            selectedTab = .record
            startRecordingTrigger.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("stopDreamRecording"))) { _ in
            if isRecording {
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    isRecording = false
                    isPaused = false
                }
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "reveri" else { return }
        switch url.host {
        case "record":
            AnalyticsService.track(.deepLinkRecord)
            guard !isRecording && !isReviewing else { return }
            selectedTab = .record
            showDeepLinkRecordConfirmation = true
        case "write":
            AnalyticsService.track(.deepLinkWrite)
            selectedTab = .record
            startTextModeTrigger.toggle()
        case "stop-recording":
            break
        default:
            break
        }
    }

    private func saveFeelings() {
        guard let dream = savedDreamForEmotion,
              !dream.isDeleted else {
            showEmotionGrid = false
            showHowDidItFeel = false
            pendingEmotions = []
            return
        }
        let emotionNames = pendingEmotions.map { $0.rawValue }.joined(separator: ",")
        AnalyticsService.track(.emotionsSelected, metadata: [
            "emotions": emotionNames,
            "count": pendingEmotions.count
        ])
        dream.emotions = Array(pendingEmotions)
        dream.emotionRawValue = pendingEmotions.first?.rawValue
        try? modelContext.save()
        showEmotionGrid = false
        pendingEmotions = []
        dismissWithSaved()
    }

    private func dismissWithSaved() {
        dismissTask?.cancel()
        withAnimation(.spring(duration: 0.4)) {
            showDreamSaved = true
        }
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                showHowDidItFeel = false
            }
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            showDreamSaved = false
        }
    }
}

// MARK: - TabBarWithAudioState (isolates audioRecorder.isPlaying observation)

/// Wrapper that observes `audioRecorder.isPlaying` in its own body,
/// preventing RootView from re-evaluating ~43 times/sec.
private struct TabBarWithAudioState: View {
    @Binding var selectedTab: AppTab
    let emotionFilter: DreamEmotion?
    let isRecording: Bool
    let isPaused: Bool
    let isReviewing: Bool
    let isSavingFeelings: Bool
    let canSaveFeelings: Bool
    let onStop: () -> Void
    let onTogglePause: () -> Void
    let onTogglePreview: () -> Void
    let onDelete: () -> Void
    let onSkipBack: () -> Void
    let onSkipForward: () -> Void
    let onSaveFeelings: () -> Void
    let isInDetailDreamTab: Bool
    let hasGeneratedImage: Bool
    let isGeneratingImage: Bool
    let onGenerateImage: () -> Void
    let detailState: DetailDreamState
    var audioRecorder: AudioRecorder  // Reference only — read .isPlaying inside body
    var audioPlaybackService: AudioPlaybackService

    var body: some View {
        ReveriTabBar(
            selectedTab: $selectedTab,
            emotionFilter: emotionFilter,
            isRecording: isRecording,
            isPaused: isPaused,
            isReviewing: isReviewing,
            isPlayingPreview: audioRecorder.isPlaying,  // ← Observation happens HERE, not in RootView
            isSavingFeelings: isSavingFeelings,
            canSaveFeelings: canSaveFeelings,
            onStop: onStop,
            onTogglePause: onTogglePause,
            onTogglePreview: onTogglePreview,
            onDelete: onDelete,
            onSkipBack: onSkipBack,
            onSkipForward: onSkipForward,
            onSaveFeelings: onSaveFeelings,
            isInDetailDreamTab: isInDetailDreamTab,
            hasGeneratedImage: hasGeneratedImage,
            isGeneratingImage: isGeneratingImage,
            onGenerateImage: onGenerateImage,
            detailState: detailState
        )
        .onChange(of: audioPlaybackService.isPlaying) { _, playing in
            if playing && audioRecorder.isPlaying {
                audioRecorder.togglePlayback()
            }
        }
    }
}
