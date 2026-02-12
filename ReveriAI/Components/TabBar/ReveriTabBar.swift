import SwiftUI

struct ReveriTabBar: View {
    @Binding var selectedTab: AppTab
    @Environment(\.theme) private var theme
    @State private var expandedTab: AppTab?
    @State private var collapseTask: Task<Void, Never>?
    @State private var pauseFlipCount: Int = 0
    @State private var previewFlipCount: Int = 0
    var isRecording: Bool = false
    var isPaused: Bool = false
    var isReviewing: Bool = false
    var isPlayingPreview: Bool = false
    var onStop: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onTogglePreview: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        Group {
            if isRecording {
                recordingControls
                    .transition(.blurReplace)
            } else if isReviewing {
                reviewControls
                    .transition(.blurReplace)
            } else {
                normalTabs
                    .transition(.blurReplace)
            }
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
                TabBarItem(
                    activeIcon: tab.activeIcon,
                    inactiveIcon: tab.inactiveIcon,
                    label: tab.label,
                    isSelected: selectedTab == tab,
                    isExpanded: expandedTab == tab,
                    accentColor: theme.accent
                ) {
                    handleTap(tab)
                }
            }
        }
    }

    private var recordingControls: some View {
        let stopColor = Color(hex: "FF3F42")

        return HStack(spacing: 4) {
            // Stop button — always shows label
            Button {
                onStop?()
            } label: {
                HStack(spacing: 6) {
                    Image("StopIcon")
                        .renderingMode(.original)
                        .frame(width: 22, height: 22)
                    Text("Stop")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(-0.08)
                        .foregroundStyle(stopColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(stopColor.opacity(0.1))
                )
            }
            .buttonStyle(.plain)

            // Pause/Resume button
            Button {
                withAnimation(.spring(duration: 0.7, bounce: 0.1)) {
                    onTogglePause?()
                    pauseFlipCount += 1
                }
            } label: {
                Image(isPaused ? "PlayIcon" : "PauseIcon")
                    .renderingMode(.original)
                    .frame(width: 22, height: 22)
                    .rotation3DEffect(
                        .degrees(Double(pauseFlipCount) * 360),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.4
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    private var reviewControls: some View {
        HStack(spacing: 4) {
            // Preview/Play button
            Button {
                withAnimation(.spring(duration: 0.7, bounce: 0.1)) {
                    onTogglePreview?()
                    previewFlipCount += 1
                }
            } label: {
                HStack(spacing: 6) {
                    Image(isPlayingPreview ? "PauseIcon" : "PlayIcon")
                        .renderingMode(.original)
                        .frame(width: 22, height: 22)
                        .rotation3DEffect(
                            .degrees(Double(previewFlipCount) * 360),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.4
                        )
                    Text("Preview")
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
                onDelete?()
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
