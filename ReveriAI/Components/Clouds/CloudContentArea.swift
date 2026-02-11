import SwiftUI

struct CloudContentArea<Pill: View, Content: View>: View {
    @Environment(\.theme) private var theme

    let cloudHeight: CGFloat
    let pill: Pill
    let content: Content

    init(
        cloudHeight: CGFloat,
        @ViewBuilder pill: () -> Pill,
        @ViewBuilder content: () -> Content
    ) {
        self.cloudHeight = cloudHeight
        self.pill = pill()
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Content pushed below cloud region
            VStack(spacing: 0) {
                Color.clear.frame(height: cloudHeight)
                content
            }

            // Cloud shapes
            CloudSeparator()
                .frame(height: cloudHeight)
                .allowsHitTesting(false)

            // Mode pill on the clouds, right-aligned
            HStack {
                Spacer()
                pill.padding(.trailing, 16)
            }
            .padding(.top, cloudHeight / 2 - 4)
        }
        .background(theme.cloudFront)
    }
}
