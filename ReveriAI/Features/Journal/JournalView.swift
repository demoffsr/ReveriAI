import SwiftUI
import SwiftData

struct JournalView: View {
    @Binding var selectedEmotion: DreamEmotion?
    @Environment(\.theme) private var theme
    @State private var viewModel = JournalViewModel()
    @Query(sort: \Dream.createdAt, order: .reverse) private var allDreams: [Dream]

    private var filteredDreams: [Dream] {
        allDreams.filter { viewModel.matches($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            JournalHeader(
                searchText: $viewModel.searchText,
                selectedEmotion: $selectedEmotion
            )
            .onChange(of: selectedEmotion) { _, newValue in
                viewModel.selectedEmotion = newValue
            }

            // Time range filter
            TimeRangeFilter(selected: $viewModel.selectedTimeRange)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            // Dream list or empty state
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

            Spacer(minLength: 0)
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
    }
}
