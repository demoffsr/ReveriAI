import SwiftUI

@main
struct ReveriWatchApp: App {
    @State private var sessionManager = WatchSessionManager()
    @State private var theme = WatchThemeManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRecordingView()
                .environment(sessionManager)
                .environment(theme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                theme.refresh()
            }
        }
    }
}
