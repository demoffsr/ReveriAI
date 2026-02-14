import SwiftUI
import SwiftData

struct JournalView: View {
    private enum JournalTab {
        case dreams
        case folders
    }

    @Binding var selectedEmotion: DreamEmotion?
    @Environment(\.theme) private var theme
    @State private var viewModel = JournalViewModel()
    @State private var selectedTab: JournalTab = .dreams
    @Query(sort: \Dream.createdAt, order: .reverse) private var allDreams: [Dream]

    private var filteredDreams: [Dream] {
        allDreams.filter { viewModel.matches($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            JournalHeader(
                searchText: $viewModel.searchText,
                selectedEmotion: $selectedEmotion,
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
                if filteredDreams.isEmpty {
                    EmptyJournalView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredDreams, id: \.id) { dream in
                                DreamCard(dream: dream)
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
    }
}
