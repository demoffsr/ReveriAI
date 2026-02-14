import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .record
    @State private var showEmotionPicker = false
    @State private var savedDreamForEmotion: Dream?
    @State private var isRecording = false
    @State private var isPaused = false
    @State private var isReviewing = false
    @State private var audioRecorder = AudioRecorder()
    @State private var speechService = SpeechRecognitionService()

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
                        speechService: speechService
                    ) { dream in
                        savedDreamForEmotion = dream
                        showEmotionPicker = true
                    }
                case .journal:
                    JournalView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            ReveriTabBar(
                selectedTab: $selectedTab,
                isRecording: isRecording,
                isPaused: isPaused,
                isReviewing: isReviewing,
                isPlayingPreview: audioRecorder.isPlaying,
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
                }
            )
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showEmotionPicker) {
            EmotionGrid(dream: savedDreamForEmotion)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}
