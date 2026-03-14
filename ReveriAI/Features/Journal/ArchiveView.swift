import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Binding var isInDetailDreamTab: Bool
    @Binding var detailDreamHasImage: Bool
    @Binding var detailDreamIsGenerating: Bool
    @Binding var detailDreamGenerateTrigger: Bool
    var detailState: DetailDreamState

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Query(sort: \Dream.createdAt, order: .reverse) private var allDreams: [Dream]
    @State private var selectedDream: Dream?

    private var archivedDreams: [Dream] {
        allDreams.filter { $0.isArchived }
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar

            if archivedDreams.isEmpty {
                emptyState
            } else {
                dreamsList
            }
        }
        .background((theme.isDayTime ? Color(.systemGroupedBackground) : .darkBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .navigationDestination(item: $selectedDream) { dream in
            DreamDetailView(
                dream: dream,
                isInDetailDreamTab: $isInDetailDreamTab,
                detailDreamHasImage: $detailDreamHasImage,
                detailDreamIsGenerating: $detailDreamIsGenerating,
                detailDreamGenerateTrigger: $detailDreamGenerateTrigger,
                detailState: detailState
            )
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
                        .foregroundStyle(theme.textPrimary.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
                .reveriGlass(.circle)

                Spacer()

                Text(String(localized: "archive.title", defaultValue: "Archive"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            String(localized: "archive.empty", defaultValue: "No archived dreams"),
            systemImage: "archivebox",
            description: Text(String(localized: "archive.emptyDescription", defaultValue: "Archived dreams will appear here"))
        )
        .frame(maxHeight: .infinity)
    }

    // MARK: - Dreams List

    private var dreamsList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(archivedDreams, id: \.id) { dream in
                    DreamCard(dream: dream, isArchiveMode: true) {
                        selectedDream = dream
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
    }
}
