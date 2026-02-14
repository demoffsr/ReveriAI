import SwiftUI

struct DreamDetailView: View {
    let dream: Dream
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !dream.title.isEmpty {
                    Text(dream.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)
                }

                if !dream.text.isEmpty {
                    Text(dream.text)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(dream.title.isEmpty ? "Dream" : dream.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
