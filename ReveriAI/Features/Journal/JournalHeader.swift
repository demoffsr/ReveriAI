import SwiftUI

struct JournalHeader: View {
    @Binding var searchText: String
    @Binding var selectedEmotion: DreamEmotion?
    @AppStorage("speechRecognitionLocale") private var selectedLocaleId: String = SpeechLocale.defaultLocale.identifier
    @Environment(\.theme) private var theme

    private var selectedLocale: SpeechLocale {
        SpeechLocale(rawValue: selectedLocaleId) ?? .defaultLocale
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Locale picker + Search bar
            HStack(spacing: 12) {
                // Locale picker
                Menu {
                    ForEach(SpeechLocale.allCases) { locale in
                        Button {
                            selectedLocaleId = locale.identifier
                        } label: {
                            HStack {
                                Text(locale.displayName)
                                if locale == selectedLocale {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(selectedLocale.shortCode)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }

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
