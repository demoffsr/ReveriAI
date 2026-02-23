import SwiftUI
import SwiftData
import os

private let launchLog = Logger(subsystem: "com.reveri", category: "Launch")

@main
struct ReveriAIApp: App {
    @State private var theme = ThemeManager()
    @State private var modelContainer: ModelContainer?
    @State private var loaderOpacity: Double = 1.0
    @State private var loaderRemoved = false

    init() {
        // INSTANT init — no heavy work. ModelContainer created after first frame.
        let hour = Calendar.current.component(.hour, from: .now)
        if hour >= 5 && hour < 21 {
            UIWindow.appearance().backgroundColor = UIColor(red: 1.0, green: 0.667, blue: 0.0, alpha: 1)
        } else {
            UIWindow.appearance().backgroundColor = UIColor(red: 0.055, green: 0.055, blue: 0.102, alpha: 1)
        }
        launchLog.info("⏱ App.init done (no ModelContainer)")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let modelContainer {
                    RootView()
                        .modelContainer(modelContainer)
                }

                if !loaderRemoved {
                    LoaderView()
                        .opacity(loaderOpacity)
                        .allowsHitTesting(false)
                        .zIndex(1)
                }
            }
            .background(Color(hex: theme.isDayTime ? "FFAA00" : "0E0E1A").ignoresSafeArea())
            .environment(\.theme, theme)
            .task {
                let t0 = CFAbsoluteTimeGetCurrent()
                launchLog.info("⏱ .task started (first frame done)")

                // Notification setup — fire and forget
                Task.detached(priority: .userInitiated) {
                    await NotificationService.setupDelegate()
                }

                // Yield so system gesture gate completes on lightweight first frame
                try? await Task.sleep(for: .milliseconds(50))
                launchLog.info("⏱ After yield: \(Int((CFAbsoluteTimeGetCurrent() - t0) * 1000))ms")

                // Create ModelContainer on main thread (fast, ~560ms first launch)
                let t1 = CFAbsoluteTimeGetCurrent()
                let container: ModelContainer
                do {
                    container = try ModelContainer(for: Dream.self, DreamFolder.self)
                } catch {
                    fatalError("Failed to create ModelContainer: \(error)")
                }
                launchLog.info("⏱ ModelContainer: \(Int((CFAbsoluteTimeGetCurrent() - t1) * 1000))ms")

                // Mount RootView
                modelContainer = container

                // Let RootView render
                try? await Task.sleep(for: .milliseconds(100))
                launchLog.info("⏱ RootView rendered: \(Int((CFAbsoluteTimeGetCurrent() - t0) * 1000))ms")

                // Fade loader
                withAnimation(.easeOut(duration: 0.3)) {
                    loaderOpacity = 0
                }
                try? await Task.sleep(for: .milliseconds(300))
                loaderRemoved = true
                launchLog.info("⏱ Total launch: \(Int((CFAbsoluteTimeGetCurrent() - t0) * 1000))ms")
            }
        }
    }
}
