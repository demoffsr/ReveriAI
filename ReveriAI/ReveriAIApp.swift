import SwiftUI
import SwiftData
import os

private let launchLog = Logger(subsystem: "com.reveri", category: "Launch")

@main
struct ReveriAIApp: App {
    let modelContainer: ModelContainer
    @State private var theme = ThemeManager()
    @State private var loaderOpacity: Double = 0.99  // NOT 1.0 — prevents GPU occlusion culling
    @State private var rootReady = false
    @State private var loaderDismissed = false

    init() {
        let t0 = CFAbsoluteTimeGetCurrent()

        // Match LaunchBackground for seamless system launch → LoaderView transition
        let hour = Calendar.current.component(.hour, from: .now)
        if hour >= 5 && hour < 21 {
            UIWindow.appearance().backgroundColor = UIColor(red: 1.0, green: 0.667, blue: 0.0, alpha: 1)
        } else {
            UIWindow.appearance().backgroundColor = UIColor(red: 0.055, green: 0.055, blue: 0.102, alpha: 1)
        }

        // Pre-create ModelContainer during iOS launch screen phase —
        // removes synchronous DB creation from body evaluation frame
        let t1 = CFAbsoluteTimeGetCurrent()
        do {
            modelContainer = try ModelContainer(for: Dream.self, DreamFolder.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        launchLog.info("⏱ ModelContainer: \(Int((CFAbsoluteTimeGetCurrent() - t1) * 1000))ms")
        launchLog.info("⏱ App.init total: \(Int((CFAbsoluteTimeGetCurrent() - t0) * 1000))ms")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Always mounted — heavy body eval happens DURING iOS launch screen,
                // not after (avoids main thread block when app is interactive)
                RootView(onReady: {
                    rootReady = true
                })

                if !loaderDismissed {
                    LoaderView()
                        .opacity(loaderOpacity)
                        .allowsHitTesting(loaderOpacity > 0)
                        .zIndex(1)
                }
            }
            .background(Color(hex: theme.isDayTime ? "FFAA00" : "0E0E1A").ignoresSafeArea())
            .environment(\.theme, theme)
            .modelContainer(modelContainer)
            .task {
                let taskStart = CFAbsoluteTimeGetCurrent()

                // Notification setup in background — fire and forget
                Task.detached(priority: .userInitiated) {
                    NotificationService.setupDelegate()
                }

                // Wait for RootView ready + minimum display time for animation
                let minimum = Task { try? await Task.sleep(for: .seconds(1.8)) }
                while !rootReady {
                    try? await Task.sleep(for: .milliseconds(50))
                }
                launchLog.info("⏱ rootReady: \(Int((CFAbsoluteTimeGetCurrent() - taskStart) * 1000))ms")
                _ = await minimum.value  // ensure loader shows at least 1.8s

                // Fade out loader
                withAnimation(.easeOut(duration: 0.5)) {
                    loaderOpacity = 0
                }
                try? await Task.sleep(for: .milliseconds(500))
                loaderDismissed = true
                launchLog.info("⏱ Total launch: \(Int((CFAbsoluteTimeGetCurrent() - taskStart) * 1000))ms")
            }
        }
    }
}
