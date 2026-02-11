import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = RecordViewModel()
    @FocusState private var isTextFocused: Bool

    var onDreamSaved: ((Dream) -> Void)?

    private let cloudHeight: CGFloat = 159
    private let baseHeaderHeight: CGFloat = 220

    private var headerRatio: CGFloat {
        isTextFocused ? 0.45 : 1.0
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

                // Layer 2: Header + clouds (on top, clouds bridge the boundary)
                headerWithClouds
            }
            .ignoresSafeArea(edges: .top)
            .animation(.easeOut(duration: 0.3), value: isTextFocused)

            // Bottom action bar
            bottomActionBar
                .padding(.bottom, 90)

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
    }

    // MARK: - Header + Clouds

    private var headerWithClouds: some View {
        DreamHeader(compressionRatio: headerRatio)
            .frame(height: headerHeight)
            .overlay(alignment: .bottom) {
                CloudSeparator()
                    .frame(height: cloudHeight)
                    .offset(y: cloudOverhang)
                    .allowsHitTesting(false)
            }
    }

    // MARK: - Content

    private var contentArea: some View {
        VStack(spacing: 0) {
            // Reserve space for header + cloud overhang
            Color.clear
                .frame(height: headerHeight + cloudOverhang)

            // Mode pill, right-aligned
            HStack {
                Spacer()
                modeSwitchPill
                    .padding(.trailing, 16)
            }
            .padding(.top, 8)

            // Text editor or voice placeholder
            if viewModel.mode == .text {
                TextModeView(
                    text: $viewModel.dreamText,
                    isFocused: $isTextFocused
                )
                .padding(.top, 12)
            } else {
                voicePlaceholder
            }

            Spacer()

            // Live captions placeholder
            if viewModel.mode == .voice {
                Text("Live Captions will appear here")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 160)
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
                Image(systemName: viewModel.mode == .voice ? "waveform" : "pencil.line")
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                Text(viewModel.mode == .voice ? "Voice Mode" : "Text Mode")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            // Record / Save button
            Button {
                if viewModel.mode == .text && viewModel.canSave {
                    viewModel.saveDream(context: modelContext)
                    isTextFocused = false
                    if let dream = viewModel.savedDream {
                        onDreamSaved?(dream)
                    }
                }
            } label: {
                ZStack {
                    // Warm glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    theme.accent.opacity(0.35),
                                    theme.accent.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 28
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "moon.fill")
                        .font(.title2)
                        .foregroundStyle(theme.accent)
                }
            }
            .buttonStyle(.plain)

            // Attach / Clipboard button
            Button {
                // Attachment — future implementation
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        )
    }

    // MARK: - Voice Placeholder

    private var voicePlaceholder: some View {
        VStack {
            Spacer()
            Spacer()
        }
    }
}
