import Foundation
import Supabase
import os

enum AuthService {
    private static let logger = Logger(subsystem: "com.reveri", category: "Auth")

    /// Current Supabase Auth user ID (set after ensureAuthenticated).
    private(set) static var currentUserId: String?

    /// Ensures a valid anonymous session exists.
    /// Call once at app launch. supabase-swift auto-persists the session
    /// in Keychain across launches. On subsequent launches, the existing
    /// session is restored automatically.
    static func ensureAuthenticated() async {
        let client = SupabaseService.client

        do {
            let session = try await client.auth.session
            setUserId(session.user.id.uuidString)
            logger.info("Existing session: \(session.user.id)")
            return
        } catch {
            logger.info("No session, signing in anonymously")
        }

        do {
            let session = try await client.auth.signInAnonymously()
            setUserId(session.user.id.uuidString)
            logger.info("Anonymous sign-in OK: \(session.user.id)")
        } catch {
            logger.error("Anonymous sign-in failed: \(error.localizedDescription)")
        }
    }

    private static func setUserId(_ id: String) {
        currentUserId = id
        Dream.defaultUserId = id
        DreamFolder.defaultUserId = id
    }
}
