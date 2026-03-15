import Foundation

struct InterpretationData: Codable {
    let version: Int
    let emotionalCore: EmotionalCore?
    let frameworks: [FrameworkAnalysis]?
    let symbols: [SymbolAnalysis]?
    let reflection: [String]?
    let synthesis: String?
    let text: String?

    struct EmotionalCore: Codable {
        let title: String
        let body: String
    }

    struct FrameworkAnalysis: Codable {
        let id: String
        let title: String
        let icon: String
        let body: String
    }

    struct SymbolAnalysis: Codable {
        let symbol: String
        let meaning: String
    }

    var isV2: Bool {
        version >= 2 && emotionalCore != nil && frameworks != nil && (frameworks?.count ?? 0) == 3
    }

    static func parse(from jsonString: String) -> InterpretationData? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(InterpretationData.self, from: data)
    }
}
