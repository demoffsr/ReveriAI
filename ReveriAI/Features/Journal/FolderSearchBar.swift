import SwiftUI

struct FolderSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(.black.opacity(0.4))
            TextField("Search", text: $text)
                .font(.system(size: 17))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(.white)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(.black.opacity(0.1), lineWidth: 1)
        )
    }
}
