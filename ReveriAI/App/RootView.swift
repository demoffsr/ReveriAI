import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .record
    @State private var showEmotionPicker = false
    @State private var savedDreamForEmotion: Dream?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .record:
                    RecordView { dream in
                        savedDreamForEmotion = dream
                        showEmotionPicker = true
                    }
                case .journal:
                    JournalView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            ReveriTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showEmotionPicker) {
            EmotionGrid(dream: savedDreamForEmotion)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}
