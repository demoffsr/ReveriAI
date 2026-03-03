import SwiftUI
import SwiftData

struct FolderPickerSheet: View {
    let dream: Dream
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DreamFolder.createdAt, order: .reverse) private var folders: [DreamFolder]
    @State private var searchText = ""
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var cachedFilteredFolders: [DreamFolder] = []
    @State private var searchDebounceTask: Task<Void, Never>?

    private func updateFilteredFolders() {
        if searchText.isEmpty {
            cachedFilteredFolders = folders
        } else {
            cachedFilteredFolders = folders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                FolderSearchBar(text: $searchText)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if cachedFilteredFolders.isEmpty {
                    ContentUnavailableView(String(localized: "folder.noFolders", defaultValue: "No folders"), systemImage: "folder", description: Text(String(localized: "folder.createFirst", defaultValue: "Create a folder first")))
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(cachedFilteredFolders, id: \.id) { folder in
                                FolderCard(folder: folder, onTap: {
                                    AnalyticsService.track(.dreamMovedToFolder)
                                    dream.folder = folder
                                    try? modelContext.save()
                                    dismiss()
                                })
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "folder.addToFolder", defaultValue: "Add to Folder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newFolderName = ""
                        showNewFolderAlert = true
                    } label: {
                        Image("FolderCreateIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .onAppear { updateFilteredFolders() }
            .onChange(of: folders.count) { _, _ in updateFilteredFolders() }
            .onChange(of: searchText) { _, _ in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    updateFilteredFolders()
                }
            }
            .alert(String(localized: "folder.newFolder", defaultValue: "New Folder"), isPresented: $showNewFolderAlert) {
                TextField(String(localized: "folder.folderName", defaultValue: "Folder name"), text: $newFolderName)
                Button(String(localized: "folder.create", defaultValue: "Create")) {
                    guard !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let folder = DreamFolder(name: newFolderName.trimmingCharacters(in: .whitespaces))
                    modelContext.insert(folder)
                    try? modelContext.save()
                    AnalyticsService.track(.folderCreated)
                }
                Button(String(localized: "folder.cancel", defaultValue: "Cancel"), role: .cancel) {}
            }
        }
    }
}
