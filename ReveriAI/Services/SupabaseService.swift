import Foundation
import Supabase
import os

enum SupabaseService {
    private static let logger = Logger(subsystem: "com.reveri", category: "Supabase")

    static let client: SupabaseClient = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        let session = URLSession(configuration: config)

        return SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.projectURL)!,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(global: .init(session: session))
        )
    }()

    /// Executes an async operation with retry and exponential backoff.
    /// Retries only on transient errors (timeouts, network loss, 5xx).
    /// - Parameters:
    ///   - maxAttempts: Total attempts (default 3 = 1 initial + 2 retries)
    ///   - operation: The async throwing closure to retry
    static func withRetry<T>(
        maxAttempts: Int = 3,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Swift.Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                guard attempt < maxAttempts, isTransient(error) else {
                    break
                }
                let delay = pow(2.0, Double(attempt)) // 2s, 4s
                logger.warning("Retry \(attempt)/\(maxAttempts) after \(Int(delay))s — \(error.localizedDescription)")
                try? await Task.sleep(for: .seconds(delay))
            }
        }
        throw lastError!
    }

    /// Returns true for errors worth retrying (timeouts, network, 5xx).
    private static func isTransient(_ error: Swift.Error) -> Bool {
        // URLSession errors: timeout, network lost, not connected
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .cannotConnectToHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }

        // Supabase FunctionsError with 5xx status
        let desc = String(describing: error)
        if desc.contains("5") && (desc.contains("status") || desc.contains("Status")) {
            return true
        }

        // DreamAIService retriable errors (serviceUnavailable, hallucination)
        if let aiError = error as? DreamAIService.Error, aiError.isRetriable {
            return true
        }

        return false
    }
}
