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
    @State private var phoneSessionManager = PhoneSessionManager()

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

                // Protect existing SwiftData database files
                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                let storeURL = appSupport.appendingPathComponent("default.store")
                if FileManager.default.fileExists(atPath: storeURL.path) {
                    try? FileManager.default.setAttributes(
                        [.protectionKey: FileProtectionType.complete],
                        ofItemAtPath: storeURL.path
                    )
                    for suffix in ["-wal", "-shm"] {
                        let auxPath = storeURL.path + suffix
                        if FileManager.default.fileExists(atPath: auxPath) {
                            try? FileManager.default.setAttributes(
                                [.protectionKey: FileProtectionType.complete],
                                ofItemAtPath: auxPath
                            )
                        }
                    }
                }

                // Migrate existing user files to appropriate protection levels
                FileProtectionMigration.migrateIfNeeded()

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
                phoneSessionManager.configure(with: container)

                // Ensure anonymous auth session before any Edge Function calls
                await AuthService.ensureAuthenticated()

                // Backfill userId for existing dreams/folders (one-time after update)
                backfillUserIds(container: container)

                // One-time: fix hallucinated Whisper transcripts & re-transcribe
                DreamAIService.cleanupHallucinatedTranscripts(modelContainer: container)

                // Backfill imagePath for existing dreams + cache images to disk
                DreamAIService.migrateImagePaths(modelContainer: container)
                // Retry any previously failed storage deletions
                DreamAIService.retryPendingDeletions()

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

    /// One-time backfill: tags existing dreams/folders with the current userId.
    /// Runs synchronously on main context — fast for small local datasets.
    private func backfillUserIds(container: ModelContainer) {
        guard let userId = AuthService.currentUserId else { return }
        let context = container.mainContext

        if let dreams = try? context.fetch(FetchDescriptor<Dream>(
            predicate: #Predicate<Dream> { $0.userId == nil }
        )), !dreams.isEmpty {
            for dream in dreams { dream.userId = userId }
            try? context.save()
            launchLog.info("Backfilled userId for \(dreams.count) dreams")
        }

        if let folders = try? context.fetch(FetchDescriptor<DreamFolder>(
            predicate: #Predicate<DreamFolder> { $0.userId == nil }
        )), !folders.isEmpty {
            for folder in folders { folder.userId = userId }
            try? context.save()
            launchLog.info("Backfilled userId for \(folders.count) folders")
        }
    }
}
