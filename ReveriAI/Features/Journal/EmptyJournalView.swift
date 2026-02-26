import SwiftUI

struct EmptyJournalView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("😊")
                .font(.system(size: 64))

            Text(String(localized: "journal.sweetDreams", defaultValue: "Sweet dreams ahead"))
                .font(.title3.weight(.semibold))

            Text(String(localized: "journal.tapRecord", defaultValue: "Tap Record after you wake up\nto start your journal"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
