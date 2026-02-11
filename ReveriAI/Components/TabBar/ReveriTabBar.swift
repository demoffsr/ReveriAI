import SwiftUI

struct ReveriTabBar: View {
    @Binding var selectedTab: AppTab
    @Environment(\.theme) private var theme
    @State private var expandedTab: AppTab?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                TabBarItem(
                    icon: tab.icon,
                    label: tab.label,
                    isSelected: selectedTab == tab,
                    isExpanded: expandedTab == tab,
                    accentColor: theme.accent
                ) {
                    handleTap(tab)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.bottom, 8)
    }

    private func handleTap(_ tab: AppTab) {
        if selectedTab == tab {
            // Already selected — expand to show label, then collapse
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                expandedTab = tab
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    expandedTab = nil
                }
            }
        } else {
            withAnimation(.spring(duration: 0.3)) {
                selectedTab = tab
                expandedTab = tab
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    expandedTab = nil
                }
            }
        }
    }
}
