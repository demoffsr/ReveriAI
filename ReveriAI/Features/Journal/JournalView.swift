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
    @State private var showProfile = false
    @State private var searchDebounceTask: Task<Void, Never>?
    @Query(sort: \Dream.createdAt, order: .reverse) private var allDreams: [Dream]
    @Query(sort: \DreamFolder.createdAt, order: .reverse) private var folders: [DreamFolder]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            journalContent
        }
    }

    // MARK: - Main Content

    private var journalContent: some View {
        VStack(spacing: 0) {
            JournalHeader(
                searchText: $viewModel.searchText,
                selectedEmotion: $selectedEmotion,
                emotionOrder: $emotionOrder,
                selectedTimeRange: $viewModel.selectedTimeRange,
                isFoldersTab: selectedTab == .folders,
                showNewFolderAlert: $showNewFolderAlert,
                avatarStorage: avatarStorage,
                onProfileTap: { showProfile = true }
            )

            Picker("", selection: $selectedTab) {
                Text("Dreams").tag(JournalTab.dreams)
                Text("Folders").tag(JournalTab.folders)
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
        .onChange(of: viewModel.searchText) { _, _ in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                refreshFilters()
            }
        }
        .onChange(of: viewModel.selectedTimeRange) { _, _ in refreshFilters() }
        .onChange(of: selectedDream) { _, newValue in
            if newValue == nil { isInDetailDreamTab = false }
        }
        .alert("New Folder", isPresented: $showNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") { createFolder() }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: showNewFolderAlert) { _, newValue in
            if newValue { newFolderName = "" }
        }
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
                            DreamCard(dream: dream) {
                                selectedDream = dream
                            }
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
                ContentUnavailableView("No folders yet", systemImage: "folder", description: Text("Tap \"New Folder\" to create one"))
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(folders, id: \.id) { folder in
                            FolderCard(
                                folder: folder,
                                onTap: { selectedFolder = folder },
                                onDelete: {
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
        DreamDetailView(
            dream: dream,
            isInDetailDreamTab: $isInDetailDreamTab,
            detailDreamHasImage: $detailDreamHasImage,
            detailDreamIsGenerating: $detailDreamIsGenerating,
            detailDreamGenerateTrigger: $detailDreamGenerateTrigger,
            detailState: detailDreamState
        )
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
    }
}
