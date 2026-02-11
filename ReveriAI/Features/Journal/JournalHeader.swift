import SwiftUI

struct JournalHeader: View {
    @Binding var searchText: String
    @Binding var selectedEmotion: DreamEmotion?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Avatar + Search bar
            HStack(spacing: 12) {
                // Avatar placeholder
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 16))
                    )

                // Search bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    TextField("Search", text: $searchText)
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
            }

            // Title + Emotion filters
            HStack {
                Text("My Dreams")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                EmotionFilterBar(selectedEmotion: $selectedEmotion)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 16)
        .background(theme.headerGradient.ignoresSafeArea(edges: .top))
    }
}
