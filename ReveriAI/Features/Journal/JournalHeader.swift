import SwiftUI

struct JournalHeader: View {
    @Binding var searchText: String
    @Binding var selectedEmotion: DreamEmotion?
    @Binding var selectedTimeRange: JournalViewModel.TimeRange
    var isFoldersTab: Bool
    @State private var isEmotionsExpanded = false
    @AppStorage("speechRecognitionLocale") private var selectedLocaleId: String = SpeechLocale.defaultLocale.identifier
    @Environment(\.theme) private var theme

    private var selectedLocale: SpeechLocale {
        SpeechLocale(rawValue: selectedLocaleId) ?? .defaultLocale
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Profile + Search bar + Calendar
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
                            .frame(width: 44, height: 44)
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
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.leading, 14)
                        .reveriGlass(.capsule)
                    }

                    // Calendar filter button
                    Menu {
                        ForEach(JournalViewModel.TimeRange.allCases, id: \.self) { range in
                            Button {
                                selectedTimeRange = range
                            } label: {
                                HStack {
                                    Text(range.rawValue)
                                    if range == selectedTimeRange {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image("CalendarIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                            .frame(width: 44, height: 44)
                            .reveriGlass(.circle)
                    }
                }
            }

            // Bottom row: title + filters/actions (fixed 42pt to match emotion circles)
            HStack(spacing: 24) {
                Text("My Dreams")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize()
                if isFoldersTab {
                    Spacer(minLength: 0)
                    Button {
                        // TODO: create new folder
                    } label: {
                        HStack(spacing: 6) {
                            Image("FolderAddIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                            Text("New Folder")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .reveriGlass(.capsule)
                    }
                } else {
                    EmotionFilterBar(selectedEmotion: $selectedEmotion, isExpanded: $isEmotionsExpanded)
                }
            }
            .frame(height: 42)
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
