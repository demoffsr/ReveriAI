import SwiftUI
import SwiftData

struct FolderDetailView: View {
    let folder: DreamFolder
    @Binding var isInDetailDreamTab: Bool
    @Binding var detailDreamHasImage: Bool
    @Binding var detailDreamIsGenerating: Bool
    @Binding var detailDreamGenerateTrigger: Bool
    var detailState: DetailDreamState

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedDream: Dream?
    @State private var showAddDreams = false
    @State private var cachedFilteredDreams: [Dream] = []

    private func updateFilteredDreams() {
        let sorted = folder.dreams.sorted { $0.createdAt > $1.createdAt }
        if searchText.isEmpty {
            cachedFilteredDreams = sorted
        } else {
            cachedFilteredDreams = sorted.filter {
                $0.text.localizedCaseInsensitiveContains(searchText) ||
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar

            FolderSearchBar(text: $searchText)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if cachedFilteredDreams.isEmpty {
                ContentUnavailableView("No dreams", systemImage: "moon.zzz", description: Text("Add dreams to this folder"))
                    .frame(maxHeight: .infinity)
            } else {
                dreamsList
            }
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { updateFilteredDreams() }
        .onChange(of: searchText) { _, _ in updateFilteredDreams() }
        .onChange(of: folder.dreams.count) { _, _ in updateFilteredDreams() }
        .navigationDestination(item: $selectedDream) { dream in
            DreamDetailView(
                dream: dream,
                folderName: folder.name,
                isInDetailDreamTab: $isInDetailDreamTab,
                detailDreamHasImage: $detailDreamHasImage,
                detailDreamIsGenerating: $detailDreamIsGenerating,
                detailDreamGenerateTrigger: $detailDreamGenerateTrigger,
                detailState: detailState
            )
        }
        .sheet(isPresented: $showAddDreams) {
            AddDreamsToFolderSheet(folder: folder)
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
                .reveriGlass(.circle)

                Spacer()

                Text(folder.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.black)

                Spacer()

                Button {
                    showAddDreams = true
                } label: {
                    Image("AddIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .frame(width: 44, height: 44)
                }
                .reveriGlass(.circle)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Dreams List

    private var dreamsList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(cachedFilteredDreams, id: \.id) { dream in
                    DreamCard(dream: dream) {
                        selectedDream = dream
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Add Dreams Sheet

struct AddDreamsToFolderSheet: View {
    let folder: DreamFolder
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @Query(sort: \Dream.createdAt, order: .reverse) private var allDreams: [Dream]
    @State private var searchText = ""
    @State private var cachedFilteredDreams: [Dream] = []
    @State private var searchDebounceTask: Task<Void, Never>?

    private func updateFilteredDreams() {
        // allDreams is already sorted by @Query(sort: \Dream.createdAt, order: .reverse)
        if searchText.isEmpty {
            cachedFilteredDreams = allDreams
        } else {
            cachedFilteredDreams = allDreams.filter {
                $0.text.localizedCaseInsensitiveContains(searchText) ||
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func isInFolder(_ dream: Dream) -> Bool {
        dream.folder?.id == folder.id
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FolderSearchBar(text: $searchText)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if cachedFilteredDreams.isEmpty {
                    ContentUnavailableView("No dreams", systemImage: "moon.zzz")
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(cachedFilteredDreams, id: \.id) { dream in
                                dreamRow(dream)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Dreams")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                updateFilteredDreams()
            }
            .onChange(of: searchText) { _, _ in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    updateFilteredDreams()
                }
            }
            .onChange(of: allDreams.count) { _, _ in
                updateFilteredDreams()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }

    private func dreamRow(_ dream: Dream) -> some View {
        let added = isInFolder(dream)
        let accent = theme.accent
        return Button {
            if added {
                dream.folder = nil
            } else {
                dream.folder = folder
            }
            try? modelContext.save()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dream.title.isEmpty ? String(dream.text.prefix(30)) : dream.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                    Text(dream.createdAt.dreamFormatted)
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.4))
                }

                Spacer()

                if added {
                    Image("CheckmarkIconBig")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundStyle(accent)
                } else {
                    Image("CheckmarkEmptyIcon")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.black.opacity(0.15))
                }
            }
            .padding(14)
            .background(added ? accent.opacity(0.05) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(added ? accent.opacity(0.2) : .black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
