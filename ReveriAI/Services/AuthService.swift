import Foundation
import Supabase
import os

enum AuthService {
    private static let logger = Logger(subsystem: "com.reveri", category: "Auth")

    /// Ensures a valid anonymous session exists.
    /// Call once at app launch. supabase-swift auto-persists the session
    /// in Keychain across launches. On subsequent launches, the existing
    /// session is restored automatically.
    static func ensureAuthenticated() async {
        let client = SupabaseService.client

        do {
            let session = try await client.auth.session
            logger.info("Existing session: \(session.user.id)")
            return
        } catch {
            logger.info("No session, signing in anonymously")
        }

        do {
            let session = try await client.auth.signInAnonymously()
            logger.info("Anonymous sign-in OK: \(session.user.id)")
        } catch {
            logger.error("Anonymous sign-in failed: \(error.localizedDescription)")
        }
    }
}
