import Foundation

enum SupabaseConfig {
    static let projectURL: String = {
        guard let url = Bundle.main.infoDictionary?["SUPABASE_PROJECT_URL"] as? String,
              !url.isEmpty,
              !url.hasPrefix("$(") else {
            fatalError("Missing SUPABASE_PROJECT_URL. Ensure Secrets.xcconfig exists in project root.")
        }
        return url
    }()

    static let anonKey: String = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty,
              !key.hasPrefix("$(") else {
            fatalError("Missing SUPABASE_ANON_KEY. Ensure Secrets.xcconfig exists in project root.")
        }
        return key
    }()

    static let analyticsAPIKey: String = {
        guard let key = Bundle.main.infoDictionary?["ANALYTICS_API_KEY"] as? String,
              !key.isEmpty,
              !key.hasPrefix("$(") else {
            fatalError("Missing ANALYTICS_API_KEY. Ensure Secrets.xcconfig exists in project root.")
        }
        return key
    }()
}
