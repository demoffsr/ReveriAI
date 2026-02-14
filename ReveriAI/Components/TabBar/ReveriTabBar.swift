import SwiftUI

struct ReveriTabBar: View {
    @Binding var selectedTab: AppTab
    var emotionFilter: DreamEmotion?
    @Environment(\.theme) private var theme
    @State private var expandedTab: AppTab?
    @State private var collapseTask: Task<Void, Never>?
    @State private var pauseFlipCount: Int = 0
    @State private var previewFlipCount: Int = 0
    @State private var showDeleteConfirmation = false
    var isRecording: Bool = false
    var isPaused: Bool = false
    var isReviewing: Bool = false
    var isPlayingPreview: Bool = false
    var isSavingFeelings: Bool = false
    var canSaveFeelings: Bool = false
    var onStop: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onTogglePreview: (() -> Void)?
    var onDelete: (() -> Void)?
    var onSkipBack: (() -> Void)?
    var onSkipForward: (() -> Void)?
    var onSaveFeelings: (() -> Void)?

    var body: some View {
        Group {
            if isRecording {
                recordingControls
                    .transition(.blurReplace)
            } else if isReviewing {
                reviewControls
                    .transition(.blurReplace)
            } else if isSavingFeelings {
                savingFeelingsControls
                    .transition(.blurReplace)
            } else {
                normalTabs
                    .transition(.blurReplace)
            }
        }
        .alert("Delete recording?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 1))
        .glassEffect(.clear, in: .capsule)
        .shadow(color: .black.opacity(0.05), radius: 10.9, x: 0, y: 2)
        .padding(.bottom, 8)
    }

    private var normalTabs: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                let isJournalFiltered = tab == .journal && emotionFilter != nil
                let label: String = if let emotion = emotionFilter, tab == .journal {
                    emotion.displayName
                } else {
                    tab.label
                }
                let color: Color = if let emotion = emotionFilter, tab == .journal {
                    emotion.color
                } else {
                    theme.accent
                }
                let activeIcon: String = if let emotion = emotionFilter, tab == .journal {
                    emotion.journalIcon
                } else {
                    tab.activeIcon
                }
                TabBarItem(
                    activeIcon: activeIcon,
                    inactiveIcon: tab.inactiveIcon,
                    label: label,
                    isSelected: selectedTab == tab,
                    isExpanded: expandedTab == tab || isJournalFiltered,
                    accentColor: color
                ) {
                    handleTap(tab)
                }
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: emotionFilter)
    }

    private var recordingControls: some View {
        let stopColor = Color(hex: "FF3F42")

        // Icons NEVER change positions: Stop is always left, Pause/Play is always right.
        // Only the labels migrate: recording → "Stop" on left; paused → "Resume" on right.
        return HStack(spacing: 4) {
            // Left: Stop button — labeled when recording, icon-only when paused
            Button {
                onStop?()
            } label: {
                HStack(spacing: 6) {
                    Image("StopIcon")
                        .renderingMode(.original)
                        .frame(width: 22, height: 22)
                    if !isPaused {
                        Text("Stop")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(-0.08)
                            .foregroundStyle(stopColor)
                            .transition(.blurReplace)
                    }
                }
                .padding(.horizontal, isPaused ? 12 : 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isPaused ? .clear : stopColor.opacity(0.1))
                )
            }
            .buttonStyle(.plain)

            // Right: Pause/Resume button — icon-only when recording, labeled when paused
            Button {
                withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
                    onTogglePause?()
                    pauseFlipCount += 1
                }
            } label: {
                HStack(spacing: 6) {
                    Image(isPaused ? "PlayIcon" : "PauseIcon")
                        .renderingMode(.original)
                        .frame(width: 22, height: 22)
                        .rotation3DEffect(
                            .degrees(Double(pauseFlipCount) * 360),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.4
                        )
                    if isPaused {
                        Text("Resume")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(-0.08)
                            .foregroundStyle(theme.accent)
                            .transition(.blurReplace)
                    }
                }
                .padding(.horizontal, isPaused ? 16 : 12)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isPaused ? theme.accent.opacity(0.1) : .clear)
                )
            }
            .buttonStyle(.plain)
        }
        .animation(.spring(duration: 0.4, bounce: 0.15), value: isPaused)
    }

    private var reviewControls: some View {
        Group {
            if isPlayingPreview {
                playbackControls
                    .transition(.blurReplace)
            } else {
                reviewIdleControls
                    .transition(.blurReplace)
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.15), value: isPlayingPreview)
    }

    private var reviewIdleControls: some View {
        HStack(spacing: 4) {
            // Preview/Play button
            Button {
                withAnimation(.spring(duration: 0.7, bounce: 0.1)) {
                    onTogglePreview?()
                    previewFlipCount += 1
                }
            } label: {
                HStack(spacing: 6) {
                    Image("PlayIcon")
                        .renderingMode(.original)
                        .frame(width: 22, height: 22)
                        .rotation3DEffect(
                            .degrees(Double(previewFlipCount) * 360),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.4
                        )
                    Text("Play")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(-0.08)
                        .foregroundStyle(theme.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(theme.accent.opacity(0.1))
                )
            }
            .buttonStyle(.plain)

            // Delete button — icon only
            Button {
                showDeleteConfirmation = true
            } label: {
                Image("DeleteIcon")
                    .renderingMode(.original)
                    .frame(width: 22, height: 22)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 16) {
            // Skip back 5s
            Button {
                onSkipBack?()
            } label: {
                Image("SkipBack5Icon")
                    .renderingMode(.original)
                    .frame(width: 22, height: 22)
                    .padding(8)
            }
            .buttonStyle(.plain)

            // Large pause/play button
            Button {
                withAnimation(.spring(duration: 0.7, bounce: 0.1)) {
                    onTogglePreview?()
                    previewFlipCount += 1
                }
            } label: {
                Image(isPlayingPreview ? "PauseIcon" : "PlayIcon")
                    .renderingMode(.original)
                    .frame(width: 22, height: 22)
                    .rotation3DEffect(
                        .degrees(Double(previewFlipCount) * 360),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.4
                    )
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(theme.accent.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)

            // Skip forward 5s
            Button {
                onSkipForward?()
            } label: {
                Image("SkipForward5Icon")
                    .renderingMode(.original)
                    .frame(width: 22, height: 22)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
    }

    private var savingFeelingsControls: some View {
        // Save feelings button only — no journal icon during emotion selection
        Button {
            onSaveFeelings?()
        } label: {
            HStack(spacing: 6) {
                Image("CheckmarkBigIcon")
                    .renderingMode(.original)
                    .frame(width: 22, height: 22)
                Text("Save feelings")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(-0.08)
                    .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(canSaveFeelings ? theme.accent.opacity(0.1) : .clear)
                )
            .opacity(canSaveFeelings ? 1.0 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!canSaveFeelings)
    }

    private func handleTap(_ tab: AppTab) {
        collapseTask?.cancel()

        if expandedTab == tab {
            expandedTab = nil
        }

        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            selectedTab = tab
            expandedTab = tab
        }

        collapseTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                expandedTab = nil
            }
        }
    }
}
