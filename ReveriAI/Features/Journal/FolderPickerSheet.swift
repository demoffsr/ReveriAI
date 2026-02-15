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

    private var filteredFolders: [DreamFolder] {
        if searchText.isEmpty { return folders }
        return folders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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

                if filteredFolders.isEmpty {
                    ContentUnavailableView("No folders", systemImage: "folder", description: Text("Create a folder first"))
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(filteredFolders, id: \.id) { folder in
                                FolderCard(folder: folder, onTap: {
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
            .navigationTitle("Add to Folder")
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
            .alert("New Folder", isPresented: $showNewFolderAlert) {
                TextField("Folder name", text: $newFolderName)
                Button("Create") {
                    guard !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let folder = DreamFolder(name: newFolderName.trimmingCharacters(in: .whitespaces))
                    modelContext.insert(folder)
                    try? modelContext.save()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
