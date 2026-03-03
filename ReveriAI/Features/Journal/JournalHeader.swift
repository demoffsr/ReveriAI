import SwiftUI

struct JournalHeader: View {
    @Binding var searchText: String
    @Binding var selectedEmotion: DreamEmotion?
    @Binding var emotionOrder: [DreamEmotion]
    @Binding var selectedTimeRange: JournalViewModel.TimeRange
    var isFoldersTab: Bool
    @Binding var showNewFolderAlert: Bool
    var avatarStorage: AvatarStorage
    var isSearchActive: Bool
    @Binding var searchQuery: String
    var onProfileTap: () -> Void
    var onSearchTap: () -> Void
    var onSearchClose: () -> Void
    @State private var isEmotionsExpanded = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(alignment: .leading, spacing: 20) {
                // Profile + Search bar + Calendar
                HStack(spacing: 12) {
                    // Profile button
                    if !isSearchActive {
                        Button {
                            onProfileTap()
                        } label: {
                            if let avatarImage = avatarStorage.avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                                    .reveriGlass(.circle, interactive: false)
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .frame(width: 44, height: 44)
                                    .reveriGlass(.circle)
                            }
                        }
                    }

                    // Search + calendar/X
                    HStack(spacing: 12) {
                        // Search capsule
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))

                            ZStack(alignment: .leading) {
                                Text(String(localized: "journal.search", defaultValue: "Search"))
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .opacity(isSearchActive ? 0 : 1)

                                TextField(String(localized: "journal.searchPlaceholder", defaultValue: "Search for dream or folder..."), text: $searchQuery)
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white)
                                    .focused($isSearchFocused)
                                    .tint(.white)
                                    .submitLabel(.search)
                                    .toolbarVisibility(.hidden, for: .bottomBar)
                                    .opacity(isSearchActive ? 1 : 0)
                                    .allowsHitTesting(isSearchActive)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.leading, 14)
                        .contentShape(.capsule)
                        .reveriGlass(.capsule)
                        .onTapGesture {
                            if !isSearchActive { onSearchTap() }
                        }

                        // Calendar filter / Close search button
                        if isSearchActive {
                            Button {
                                onSearchClose()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .frame(width: 44, height: 44)
                                    .reveriGlass(.circle)
                            }
                        } else {
                            Menu {
                                ForEach(JournalViewModel.TimeRange.allCases, id: \.self) { range in
                                    Button {
                                        selectedTimeRange = range
                                    } label: {
                                        HStack {
                                            Text(range.displayName)
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
                }
                .animation(.spring(duration: 0.4, bounce: 0.1), value: isSearchActive)

                // Bottom row: title + filters/actions (fixed 42pt to match emotion circles)
                if !isSearchActive {
                    HStack(spacing: 24) {
                        Text(String(localized: "journal.myDreams", defaultValue: "My Dreams"))
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                            .fixedSize()
                        if isFoldersTab {
                            Spacer(minLength: 0)
                            Button {
                                showNewFolderAlert = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image("FolderAddIcon")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 22, height: 22)
                                    Text(String(localized: "folder.newFolder", defaultValue: "New Folder"))
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(height: 36)
                                .padding(.horizontal, 14)
                                .reveriGlass(.capsule)
                            }
                        } else {
                            EmotionFilterBar(selectedEmotion: $selectedEmotion, emotionOrder: $emotionOrder, isExpanded: $isEmotionsExpanded)
                        }
                    }
                    .frame(height: 42)
                } else {
                    Color.clear.frame(height: 42)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 68)
        .padding(.bottom, 16)
        .onChange(of: isSearchActive) { _, active in
            if active {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            } else {
                isSearchFocused = false
            }
        }
        .background {
            ZStack {
                Color.black

                // Blur gradient orb
                (theme.isDayTime ? Color(red: 1, green: 0.67, blue: 0) : Color(red: 0, green: 0.67, blue: 1))
                    .frame(width: 189, height: 196)
                    .blur(radius: 100)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .clipped()
            .ignoresSafeArea(edges: .top)
            .opacity(isSearchActive ? 0 : 1)
        }
    }
}
