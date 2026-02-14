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
    @State private var showHowDidItFeel = false
    @State private var showEmotionGrid = false
    @State private var showDreamSaved = false
    @State private var pendingEmotions: Set<DreamEmotion> = []
    @State private var autoDismissTask: Task<Void, Never>?
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
                    JournalView(selectedEmotion: $selectedEmotionFilter)
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

            // Custom tab bar
            ReveriTabBar(
                selectedTab: $selectedTab,
                emotionFilter: selectedEmotionFilter,
                isRecording: isRecording,
                isPaused: isPaused,
                isReviewing: isReviewing,
                isPlayingPreview: audioRecorder.isPlaying,
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
                }
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
        withAnimation(.spring(duration: 0.4)) {
            showDreamSaved = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.35)) {
                showHowDidItFeel = false
            }
            try? await Task.sleep(for: .seconds(0.4))
            showDreamSaved = false
        }
    }
}
