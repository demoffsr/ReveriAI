import Foundation
import Supabase
import os

enum AuthService {
    private static let logger = Logger(subsystem: "com.reveri", category: "Auth")

    /// Current Supabase Auth user ID (set after ensureAuthenticated).
    private(set) static var currentUserId: String?

    /// Whether authentication completed successfully.
    private(set) static var isAuthenticated: Bool = false

    /// Ensures a valid anonymous session exists.
    /// Call once at app launch. supabase-swift auto-persists the session
    /// in Keychain across launches. On subsequent launches, the existing
    /// session is restored automatically.
    /// Retries up to 3 times with exponential backoff on failure.
    static func ensureAuthenticated() async {
        let client = SupabaseService.client

        // Try restoring existing session first
        do {
            let session = try await client.auth.session
            setUserId(session.user.id.uuidString)
            logger.info("Existing session: \(session.user.id)")
            return
        } catch {
            logger.info("No session, signing in anonymously")
        }

        // Anonymous sign-in with retry
        let maxRetries = 3
        for attempt in 1...maxRetries {
            do {
                let session = try await client.auth.signInAnonymously()
                setUserId(session.user.id.uuidString)
                logger.info("Anonymous sign-in OK: \(session.user.id)")
                return
            } catch {
                logger.error("Anonymous sign-in attempt \(attempt)/\(maxRetries) failed: \(error.localizedDescription)")
                if attempt < maxRetries {
                    let delay = UInt64(pow(2.0, Double(attempt))) // 2s, 4s
                    try? await Task.sleep(for: .seconds(delay))
                }
            }
        }
        logger.error("Anonymous sign-in failed after \(maxRetries) attempts — AI features will be unavailable")
    }

    private static func setUserId(_ id: String) {
        currentUserId = id
        isAuthenticated = true
        Dream.defaultUserId = id
        DreamFolder.defaultUserId = id
    }
}
