import Auth
import Foundation
import Supabase
import os

enum AuthService {
    private static let logger = Logger(subsystem: "com.reveri", category: "Auth")

    /// Current Supabase Auth user ID (set after ensureAuthenticated).
    private(set) static var currentUserId: String?

    /// Whether authentication completed successfully.
    private(set) static var isAuthenticated: Bool = false

    /// Prevents infinite re-auth loops (handleAuthFailure → ensureAuthenticated → 401 → handleAuthFailure).
    private static var isReAuthenticating = false

    /// Ensures a valid anonymous session exists.
    /// Force-clears stored session and creates fresh to avoid corrupted Keychain state.
    static func ensureAuthenticated() async {
        let client = SupabaseService.client

        // TEMPORARY: Force fresh session to debug 401 issues.
        // Clear any stored session (may be corrupted from refresh token experiments).
        logger.info("Force-clearing stored session for fresh sign-in")
        try? await client.auth.signOut()

        // Anonymous sign-in with retry
        let maxRetries = 3
        for attempt in 1...maxRetries {
            do {
                let session = try await client.auth.signInAnonymously()
                setUserId(session.user.id.uuidString)
                let tokenPrefix = String(session.accessToken.prefix(20))
                logger.info("Fresh anonymous sign-in OK: \(session.user.id) token=\(tokenPrefix)...")
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

    /// Returns a fresh access token from the SDK (auto-refreshes if expired).
    /// Falls back to anon key if no session available.
    static func getValidToken() async -> String {
        do {
            let session = try await SupabaseService.client.auth.session
            return session.accessToken
        } catch {
            logger.warning("getValidToken failed: \(error.localizedDescription)")
            return SupabaseConfig.anonKey
        }
    }

    /// Called on 401 — session is corrupted on server, sign out and create fresh.
    /// Don't try refreshSession() — it returns tokens the gateway still rejects.
    static func handleAuthFailure() async {
        guard !isReAuthenticating else {
            logger.warning("Already re-authenticating, skipping")
            return
        }
        isReAuthenticating = true
        defer { isReAuthenticating = false }
        logger.info("Auth failure (401) — signing out and creating fresh anonymous session")
        try? await SupabaseService.client.auth.signOut()
        await ensureAuthenticated()
    }

    private static func setUserId(_ id: String) {
        currentUserId = id
        isAuthenticated = true
        Dream.defaultUserId = id
        DreamFolder.defaultUserId = id
    }
}
