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
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.black.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
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
