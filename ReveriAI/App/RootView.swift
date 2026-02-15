import SwiftUI
import SwiftData

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
    @State private var autoDismissTask: Task<Void, Never>?
    @State private var dismissTask: Task<Void, Never>?
    @State private var isInDetailDreamTab = false
    @State private var detailDreamHasImage = false
    @State private var detailDreamIsGenerating = false
    @State private var detailDreamGenerateTrigger = false
    @State private var detailDreamState = DetailDreamState()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .record:
                    RecordView(
                        isRecording: $isRecording,
                        isPaused: $isPaused,
                        isReviewing: $isReviewing,
                        audioRecorder: audioRecorder,
                        speechService: speechService,
                        onDreamSaved: { dream in
                            savedDreamForEmotion = dream
                        },
                        onShowHowDidItFeel: {
                            withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                                showHowDidItFeel = true
                            }
                            startAutoDismissTimer()
                        }
                    )
                case .journal:
                    JournalView(
                        selectedEmotion: $selectedEmotionFilter,
                        emotionOrder: $emotionOrder,
                        isInDetailDreamTab: $isInDetailDreamTab,
                        detailDreamHasImage: $detailDreamHasImage,
                        detailDreamIsGenerating: $detailDreamIsGenerating,
                        detailDreamGenerateTrigger: $detailDreamGenerateTrigger,
                        detailDreamState: detailDreamState
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Dismiss overlay (tap outside grid)
            if showEmotionGrid {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.4)) {
                            showEmotionGrid = false
                        }
                    }
            }

            // Emotion picker grid (above tab bar)
            if showEmotionGrid {
                EmotionPickerGrid(selectedEmotions: $pendingEmotions)
                    .padding(.bottom, 100)
            }

            // How did it feel card (floating above tab bar)
            if showHowDidItFeel && !showEmotionGrid {
                HowDidItFeelCard(
                    onTap: {
                        autoDismissTask?.cancel()
                        withAnimation(.spring(duration: 0.4)) {
                            showEmotionGrid = true
                        }
                    },
                    onDismiss: {
                        autoDismissTask?.cancel()
                        dismissWithSaved()
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
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        isRecording = false
                        isPaused = false
                    }
                },
                onTogglePause: {
                    isPaused.toggle()
                },
                onTogglePreview: {
                    audioRecorder.togglePlayback()
                },
                onDelete: {
                    audioRecorder.deleteRecording()
                    speechService.resetTranscription()
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        isReviewing = false
                    }
                },
                onSkipBack: {
                    audioRecorder.skipBackward()
                },
                onSkipForward: {
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
                audioRecorder: audioRecorder  // Reference only — NO property read in RootView
            )
        }
        .ignoresSafeArea(.keyboard)
        .animation(.spring(duration: 0.4), value: showEmotionGrid)
        .onChange(of: isRecording) { _, recording in
            if recording {
                showEmotionGrid = false
                showHowDidItFeel = false
                pendingEmotions = []
                autoDismissTask?.cancel()
            }
        }
        .onChange(of: selectedTab) { _, _ in
            if showHowDidItFeel && !showEmotionGrid {
                withAnimation(.easeOut(duration: 0.3)) {
                    showHowDidItFeel = false
                }
                autoDismissTask?.cancel()
                dismissTask?.cancel()
            }
        }
    }

    private func startAutoDismissTimer() {
        autoDismissTask?.cancel()
        autoDismissTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            if showHowDidItFeel && !showEmotionGrid {
                withAnimation(.easeOut(duration: 0.35)) {
                    showHowDidItFeel = false
                }
            }
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
            withAnimation(.easeOut(duration: 0.35)) {
                showHowDidItFeel = false
            }
            try? await Task.sleep(for: .seconds(0.4))
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
    }
}
