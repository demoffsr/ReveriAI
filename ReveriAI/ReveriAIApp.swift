import SwiftUI
import SwiftData

@main
struct ReveriAIApp: App {
    @State private var theme = ThemeManager()

    init() {
        NotificationService.setupDelegate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.theme, theme)
        }
        .modelContainer(for: [Dream.self, DreamFolder.self])
    }
}
