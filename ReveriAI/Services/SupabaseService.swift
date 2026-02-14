import Foundation
import Supabase

enum SupabaseService {
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
}
