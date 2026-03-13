import SwiftUI

struct FolderSearchBar: View {
    @Binding var text: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(theme.textSecondary)
            TextField(String(localized: "journal.search", defaultValue: "Search"), text: $text)
                .font(.system(size: 17))
                .foregroundStyle(theme.textPrimary)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(theme.cardBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(theme.cardStroke, lineWidth: 1)
        )
    }
}
