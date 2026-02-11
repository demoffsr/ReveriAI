import SwiftUI

struct ReveriTabBar: View {
    @Binding var selectedTab: AppTab
    @Environment(\.theme) private var theme
    @State private var expandedTab: AppTab?
    @State private var collapseTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                TabBarItem(
                    activeIcon: tab.activeIcon,
                    inactiveIcon: tab.inactiveIcon,
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
        .overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 1))
        .glassEffect(.clear, in: .capsule)
        .shadow(color: .black.opacity(0.05), radius: 10.9, x: 0, y: 2)
        .padding(.bottom, 8)
    }

    private func handleTap(_ tab: AppTab) {
        collapseTask?.cancel()

        if expandedTab == tab {
            expandedTab = nil
        }

        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            selectedTab = tab
            expandedTab = tab
        }

        collapseTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                expandedTab = nil
            }
        }
    }
}
