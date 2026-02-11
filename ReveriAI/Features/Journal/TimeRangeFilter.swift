import SwiftUI

struct TimeRangeFilter: View {
    @Binding var selected: JournalViewModel.TimeRange
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(JournalViewModel.TimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        selected = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.subheadline.weight(selected == range ? .semibold : .regular))
                        .foregroundStyle(selected == range ? .white : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected == range ? theme.accent : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }
}
