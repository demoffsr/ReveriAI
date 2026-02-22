import SwiftUI
import SwiftData

@main
struct ReveriAIApp: App {
    @State private var theme = ThemeManager()
    @State private var loaderOpacity: Double = 0.99  // NOT 1.0 — prevents GPU occlusion culling
    @State private var mountContent = false
    @State private var rootReady = false
    @State private var loaderDismissed = false

    init() {
        // Works BEFORE windows are created (unlike connectedScenes which is empty in init)
        // Match LaunchBackground (#FFAA00) for seamless system launch → LoaderView transition
        UIWindow.appearance().backgroundColor = UIColor(red: 1.0, green: 0.667, blue: 0.0, alpha: 1)
        NotificationService.setupDelegate()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // RootView mounts after loader renders — avoids blocking main thread
                if mountContent {
                    RootView(onReady: {
                        rootReady = true
                    })
                }

                if !loaderDismissed {
                    LoaderView()
                        .opacity(loaderOpacity)
                        .allowsHitTesting(loaderOpacity > 0)
                        .zIndex(1)
                }
            }
            .background(Color(hex: "FFAA00").ignoresSafeArea())
            .environment(\.theme, theme)
            .task {
                // Let loader render first frame
                try? await Task.sleep(for: .milliseconds(100))

                // Now mount RootView (heavy @State inits happen here)
                mountContent = true

                // Wait minimum 2s + Supabase warmup
                async let minimum: Void = Task.sleep(for: .seconds(2))
                async let services: Void = warmUp()
                _ = try? await (minimum, services)

                // Poll until RootView signals ready
                while !rootReady {
                    try? await Task.sleep(for: .milliseconds(50))
                }

                // Settle time removed — opacity 0.99 pre-warming handles GPU readiness

                withAnimation(.easeOut(duration: 0.5)) {
                    loaderOpacity = 0
                }
                try? await Task.sleep(for: .milliseconds(500))
                loaderDismissed = true
            }
        }
        .modelContainer(for: [Dream.self, DreamFolder.self])
    }

    private func warmUp() async {
        _ = SupabaseService.client

        // Pre-decode heavy images on background thread —
        // UIImage(named:) caches in NSCache, .cgImage forces PNG decode.
        // After this, SwiftUI Image() picks up already-decoded data from cache.
        await Task.detached(priority: .userInitiated) {
            for name in ["BackgroundDaylight", "SunIcon"] {
                _ = UIImage(named: name)?.cgImage
            }
        }.value
    }
}
