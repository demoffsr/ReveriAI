import SwiftUI

struct CloudSeparator: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            CloudBackShape()
                .fill(theme.cloudBack)
            CloudMidShape()
                .fill(theme.cloudMid)
            CloudFrontShape()
                .fill(theme.cloudFront)
        }
    }
}
