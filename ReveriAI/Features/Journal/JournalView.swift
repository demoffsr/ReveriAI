import SwiftUI
import SwiftData

struct JournalView: View {
    private enum JournalTab {
        case dreams
        case folders
    }

    @Binding var selectedEmotion: DreamEmotion?
    @Binding var emotionOrder: [DreamEmotion]
    @Binding var isInDetailDreamTab: Bool
    @Binding var detailDreamHasImage: Bool
    @Binding var detailDreamIsGenerating: Bool
    @Binding var detailDreamGenerateTrigger: Bool
    var detailDreamState: DetailDreamState
    var notificationService: NotificationService
    var dreamReminderManager: DreamReminderManager
    var avatarStorage: AvatarStorage
    var headerBackgroundStorage: HeaderBackgroundStorage
    @Environment(\.theme) private var theme
    @State private var viewModel = JournalViewModel()
    @State private var selectedTab: JournalTab = .dreams
    @State private var selectedDream: Dream?
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var selectedFolder: DreamFolder?
    @State private var pendingEditAction: DreamDetailView.EditAction? = nil
    @State private var showProfile = false
    @Binding var isSearchActive: Bool
    @Binding var isInProfile: Bool
    @State private var searchQuery = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @Query(sort: \Dream.createdAt, order: .reverse) private var allDreams: [Dream]
    @Query(sort: \DreamFolder.createdAt, order: .reverse) private var folders: [DreamFolder]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                journalContent
                    .opacity(isSearchActive ? 0 : 1)

                if isSearchActive {
                    SearchOverlayView(
                        dreams: allDreams,
                        folders: folders,
                        viewModel: viewModel,
                        onDreamTap: { dream in
                            selectedDream = dream
                        },
                        onFolderTap: { folder in
                            selectedFolder = folder
                        },
                        onDismiss: {
                            isSearchActive = false
                        },
                        searchQuery: $searchQuery
                    )
                    .zIndex(1)
                }

                // Header always above the dim overlay
                journalHeader
                    .ignoresSafeArea(edges: .top)
                    .zIndex(2)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }

    // MARK: - Header (above dim overlay)

    private var journalHeader: some View {
        JournalHeader(
            searchText: $viewModel.searchText,
            selectedEmotion: $selectedEmotion,
            emotionOrder: $emotionOrder,
            selectedTimeRange: $viewModel.selectedTimeRange,
            isFoldersTab: selectedTab == .folders,
            showNewFolderAlert: $showNewFolderAlert,
            avatarStorage: avatarStorage,
            isSearchActive: isSearchActive,
            searchQuery: $searchQuery,
            onProfileTap: {
                AnalyticsService.track(.profileOpened)
                showProfile = true
            },
            onSearchTap: { isSearchActive = true },
            onSearchClose: { isSearchActive = false }
        )
    }

    // MARK: - Main Content

    private var journalContent: some View {
        journalContentBase
            .onChange(of: showProfile) { _, value in
                isInProfile = value
            }
            .onChange(of: viewModel.searchText) { _, _ in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    refreshFilters()
                }
            }
            .onChange(of: viewModel.selectedTimeRange) { _, newRange in
                refreshFilters()
                AnalyticsService.track(.timeRangeChanged, metadata: ["range": "\(newRange)"])
            }
            .onChange(of: selectedTab) { _, newTab in
                AnalyticsService.track(.journalTabSwitched, metadata: ["tab": newTab == .dreams ? "dreams" : "folders"])
            }
            .onChange(of: isSearchActive) { _, active in
                if active {
                    AnalyticsService.track(.searchOpened)
                }
                if !active { searchQuery = "" }
            }
            .onChange(of: selectedDream) { _, newValue in
                if newValue == nil { isInDetailDreamTab = false }
            }
            .alert(String(localized: "folder.newFolder", defaultValue: "New Folder"), isPresented: $showNewFolderAlert) {
                TextField(String(localized: "folder.folderName", defaultValue: "Folder name"), text: $newFolderName)
                Button(String(localized: "folder.create", defaultValue: "Create")) { createFolder() }
                Button(String(localized: "folder.cancel", defaultValue: "Cancel"), role: .cancel) {}
            }
            .onChange(of: showNewFolderAlert) { _, newValue in
                if newValue { newFolderName = "" }
            }
    }

    private var journalContentBase: some View {
        journalLayout
            .navigationDestination(item: $selectedDream) { dream in
                dreamDetail(for: dream)
            }
            .navigationDestination(item: $selectedFolder) { folder in
                folderDetail(for: folder)
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView(notificationService: notificationService, dreamReminderManager: dreamReminderManager, avatarStorage: avatarStorage, headerBackgroundStorage: headerBackgroundStorage)
            }
            .onAppear { refreshFilters() }
            .onChange(of: selectedEmotion) { _, newValue in
                viewModel.selectedEmotion = newValue
                refreshFilters()
            }
            .onChange(of: allDreams) { _, _ in refreshFilters() }
    }

    private var journalLayout: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 190)

            Picker("", selection: $selectedTab) {
                Text(String(localized: "journal.dreams", defaultValue: "Dreams")).tag(JournalTab.dreams)
                Text(String(localized: "journal.folders", defaultValue: "Folders")).tag(JournalTab.folders)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Group {
                if selectedTab == .dreams {
                    dreamsContent
                        .transition(.opacity)
                } else {
                    foldersContent
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)

            Spacer(minLength: 0)
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Dreams Tab

    private var dreamsContent: some View {
        Group {
            if viewModel.filteredDreams.isEmpty {
                EmptyJournalView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(viewModel.filteredDreams, id: \.id) { dream in
                            DreamCard(dream: dream, onTap: {
                                selectedDream = dream
                            }, onEditAction: { action in
                                pendingEditAction = action
                                selectedDream = dream
                            })
                        }
                    }
                    .animation(.easeOut(duration: 0.3), value: viewModel.filteredDreams.count)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    // MARK: - Folders Tab

    private var foldersContent: some View {
        Group {
            if folders.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image("EmotionCalm")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                    Text(String(localized: "journal.noFoldersTitle", defaultValue: "Organize your dreams"))
                        .font(.title3.weight(.semibold))
                    Text(String(localized: "journal.noFoldersSubtitle", defaultValue: "Create a folder to group\nyour dreams by theme"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(folders, id: \.id) { folder in
                            FolderCard(
                                folder: folder,
                                onTap: {
                                    AnalyticsService.track(.folderOpened)
                                    selectedFolder = folder
                                },
                                onDelete: {
                                    AnalyticsService.track(.folderDeleted)
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        modelContext.delete(folder)
                                        try? modelContext.save()
                                    }
                                }
                            )
                        }
                    }
                    .animation(.easeOut(duration: 0.3), value: folders.count)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    // MARK: - Navigation Destinations

    private func dreamDetail(for dream: Dream) -> some View {
        let action = pendingEditAction
        return DreamDetailView(
            dream: dream,
            initialEditAction: action,
            isInDetailDreamTab: $isInDetailDreamTab,
            detailDreamHasImage: $detailDreamHasImage,
            detailDreamIsGenerating: $detailDreamIsGenerating,
            detailDreamGenerateTrigger: $detailDreamGenerateTrigger,
            detailState: detailDreamState
        )
        .onAppear {
            pendingEditAction = nil
        }
    }

    private func folderDetail(for folder: DreamFolder) -> some View {
        FolderDetailView(
            folder: folder,
            isInDetailDreamTab: $isInDetailDreamTab,
            detailDreamHasImage: $detailDreamHasImage,
            detailDreamIsGenerating: $detailDreamIsGenerating,
            detailDreamGenerateTrigger: $detailDreamGenerateTrigger,
            detailState: detailDreamState
        )
    }

    // MARK: - Actions

    private func refreshFilters() {
        viewModel.updateFilters(allDreams: allDreams)
    }

    private func createFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let folder = DreamFolder(name: newFolderName.trimmingCharacters(in: .whitespaces))
        modelContext.insert(folder)
        try? modelContext.save()
        AnalyticsService.track(.folderCreated)
    }
}
