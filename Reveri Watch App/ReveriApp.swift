import SwiftUI

@main
struct ReveriWatchApp: App {
    @State private var sessionManager = WatchSessionManager()
    @State private var theme = WatchThemeManager()
    @State private var shouldAutoRecord = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRecordingView(shouldAutoRecord: $shouldAutoRecord)
                .environment(sessionManager)
                .environment(theme)
                .onOpenURL { url in
                    if url.host == "record" {
                        shouldAutoRecord = true
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                theme.refresh()
            }
        }
    }
}
