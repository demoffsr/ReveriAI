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
            // Profile + Search bar
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    // Profile button with locale picker
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
                        Image(systemName: "person.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 42, height: 42)
                            .reveriGlass(.circle)
                    }

                    // Search button
                    Button {
                        // TODO: open search
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .medium))
                            Text("Search")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                        .padding(.leading, 14)
                        .reveriGlass(.capsule)
                    }
                }
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
        .padding(.top, 68)
        .padding(.bottom, 16)
        .background {
            ZStack {
                Color.black

                // Blur gradient orb
                (theme.isDayTime ? Color(red: 1, green: 0.67, blue: 0) : Color(red: 0, green: 0.67, blue: 1))
                    .frame(width: 189, height: 196)
                    .blur(radius: 100)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .drawingGroup()
            .ignoresSafeArea(edges: .top)
        }
    }
}
