import SwiftUI

struct SearchOverlayView: View {
    let dreams: [Dream]
    let folders: [DreamFolder]
    let viewModel: JournalViewModel
    var onDreamTap: (Dream) -> Void
    var onFolderTap: (DreamFolder) -> Void
    var onDismiss: () -> Void

    @Binding var searchQuery: String
    @State private var debouncedQuery = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var dragOffset: CGFloat = 0
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            // Backdrop — matches header gradient style
            ZStack {
                Color.black
                (theme.isDayTime ? Color(red: 1, green: 0.67, blue: 0) : Color(red: 0, green: 0.67, blue: 1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 120)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .drawingGroup()
            .ignoresSafeArea()
            .onTapGesture { dismiss() }

            resultsArea
                .padding(.top, 73)
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 60 {
                        dismiss()
                    } else {
                        withAnimation(.spring(duration: 0.3)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onChange(of: searchQuery) { _, _ in
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                debouncedQuery = searchQuery
            }
        }
    }

    // MARK: - Results

    private var resultsArea: some View {
        Group {
            if debouncedQuery.isEmpty {
                Spacer()
            } else if matchingDreams.isEmpty && matchingFolders.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if !matchingDreams.isEmpty {
                            ForEach(matchingDreams, id: \.id) { dream in
                                SearchDreamRow(dream: dream) {
                                    AnalyticsService.track(.searchResultTapped, metadata: ["type": "dream"])
                                    onDreamTap(dream)
                                    dismiss()
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }

                        if !matchingFolders.isEmpty {
                            ForEach(matchingFolders, id: \.id) { folder in
                                SearchFolderRow(folder: folder) {
                                    AnalyticsService.track(.searchResultTapped, metadata: ["type": "folder"])
                                    onFolderTap(folder)
                                    dismiss()
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            Text(String(localized: "search.noResults", defaultValue: "No results"))
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed

    private var matchingDreams: [Dream] {
        viewModel.searchDreams(in: dreams, query: debouncedQuery)
    }

    private var matchingFolders: [DreamFolder] {
        viewModel.searchFolders(in: folders, query: debouncedQuery)
    }

    private func dismiss() {
        onDismiss()
    }
}
