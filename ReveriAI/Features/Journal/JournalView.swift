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
    @Environment(\.theme) private var theme
    @State private var viewModel = JournalViewModel()
    @State private var selectedTab: JournalTab = .dreams
    @State private var selectedDream: Dream?
    @Query(sort: \Dream.createdAt, order: .reverse) private var allDreams: [Dream]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                JournalHeader(
                    searchText: $viewModel.searchText,
                    selectedEmotion: $selectedEmotion,
                    emotionOrder: $emotionOrder,
                    selectedTimeRange: $viewModel.selectedTimeRange,
                    isFoldersTab: selectedTab == .folders
                )
                .onChange(of: selectedEmotion) { _, newValue in
                    viewModel.selectedEmotion = newValue
                }

                // Segmented picker
                Picker("", selection: $selectedTab) {
                    Text("Dreams").tag(JournalTab.dreams)
                    Text("Folders").tag(JournalTab.folders)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Content based on selected tab
                if selectedTab == .dreams {
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
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 100)
                        }
                    }
                } else {
                    Text("Folders")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }

                Spacer(minLength: 0)
            }
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(edges: .top)
            .navigationDestination(item: $selectedDream) { dream in
                DreamDetailView(
                    dream: dream,
                    isInDetailDreamTab: $isInDetailDreamTab,
                    detailDreamHasImage: $detailDreamHasImage,
                    detailDreamIsGenerating: $detailDreamIsGenerating,
                    detailDreamGenerateTrigger: $detailDreamGenerateTrigger
                )
            }
            .onAppear {
                viewModel.updateFilters(allDreams: allDreams)
            }
            .onChange(of: allDreams) {
                viewModel.updateFilters(allDreams: allDreams)
            }
            .onChange(of: viewModel.searchText) {
                viewModel.updateFilters(allDreams: allDreams)
            }
            .onChange(of: viewModel.selectedEmotion) {
                viewModel.updateFilters(allDreams: allDreams)
            }
            .onChange(of: viewModel.selectedTimeRange) {
                viewModel.updateFilters(allDreams: allDreams)
            }
        }
    }
}
