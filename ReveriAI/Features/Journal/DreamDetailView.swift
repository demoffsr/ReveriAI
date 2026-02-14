import SwiftUI

struct DreamDetailView: View {
    let dream: Dream
    var folderName: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var selectedTab: DetailTab = .dream

    private enum DetailTab: String, CaseIterable {
        case dream = "Dream"
        case meaning = "Meaning"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom nav bar
            navBar

            // Header info (fixed)
            VStack(alignment: .leading, spacing: 0) {
                // Title
                if !dream.title.isEmpty {
                    Text(dream.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                // Emotion badges
                if !dream.emotions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(dream.emotions) { emotion in
                            EmotionTagBadge(emotion: emotion, iconSize: 18, fontSize: 13)
                        }
                    }
                    .padding(.top, 8)
                }

                // Date
                HStack(spacing: 4) {
                    Image("CalendarSmallIcon")
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text(dream.createdAt.dreamFormatted)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.black.opacity(0.35))
                .padding(.top, dream.emotions.isEmpty ? 8 : 12)

                // Segmented control
                Picker("", selection: $selectedTab) {
                    ForEach(DetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Scrollable content
            ScrollView {
                Group {
                    switch selectedTab {
                    case .dream:
                        Text(dream.text)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .tracking(-0.23)
                            .foregroundStyle(.black.opacity(0.8))
                    case .meaning:
                        Text("Coming soon...")
                            .font(.system(size: 15))
                            .foregroundStyle(.black.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
    }

    private var navBar: some View {
        HStack {
            // Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .reveriGlass(.circle)

            Spacer()

            // Center title
            VStack(spacing: 2) {
                Text("Dream")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.black)

                if let folder = folderName {
                    Text(folder)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black.opacity(0.5))
                }
            }

            Spacer()

            // Right button (options)
            Button {
                // No action yet
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .reveriGlass(.circle)
        }
        .padding(.horizontal, 16)
    }
}
