import Foundation
import Functions
import Supabase
import SwiftData
import os

enum DreamAIService {
    enum Error: Swift.Error {
        case networkError(Swift.Error)
        case emptyText
        case emptyTitle
    }

    private static let logger = Logger(subsystem: "com.reveri.ai", category: "DreamAI")

    static func generateTitle(for dreamText: String, locale: SpeechLocale) async throws -> String {
        guard !dreamText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Error.emptyText
        }

        struct RequestBody: Encodable {
            let dreamText: String
            let locale: String
        }

        struct ResponseBody: Decodable {
            let title: String
        }

        let response: ResponseBody = try await SupabaseService.client.functions.invoke(
            "generate-dream-title",
            options: .init(body: RequestBody(dreamText: dreamText, locale: locale.rawValue))
        )

        guard !response.title.isEmpty else {
            throw Error.emptyTitle
        }

        return response.title
    }

    static func generateTitleInBackground(
        dreamID: PersistentIdentifier,
        dreamText: String,
        locale: SpeechLocale,
        modelContainer: ModelContainer
    ) {
        Task { @MainActor in
            do {
                let title = try await generateTitle(for: dreamText, locale: locale)
                let context = modelContainer.mainContext
                guard let dream = context.model(for: dreamID) as? Dream else {
                    logger.warning("Dream not found for title update")
                    return
                }
                guard dream.title.isEmpty else {
                    logger.info("Dream already has a title, skipping")
                    return
                }
                dream.title = title
                try context.save()
                logger.info("Dream title generated: \(title)")
            } catch {
                logger.error("Failed to generate dream title: \(error.localizedDescription)")
            }
        }
    }
}
