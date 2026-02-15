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
        case emptyURL
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

    static func generateQuestions(for dreamText: String, locale: SpeechLocale) async throws -> [String] {
        guard !dreamText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Error.emptyText
        }

        struct RequestBody: Encodable {
            let dreamText: String
            let locale: String
        }

        struct ResponseBody: Decodable {
            let questions: [String]
        }

        let response: ResponseBody = try await SupabaseService.client.functions.invoke(
            "generate-dream-questions",
            options: .init(body: RequestBody(dreamText: dreamText, locale: locale.rawValue))
        )

        return response.questions
    }

    static func generateImage(for dreamText: String, locale: SpeechLocale, answers: [String]? = nil) async throws -> String {
        guard !dreamText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Error.emptyText
        }

        struct RequestBody: Encodable {
            let dreamText: String
            let locale: String
            let answers: [String]?
        }

        struct ResponseBody: Decodable {
            let imageURL: String
        }

        let response: ResponseBody = try await SupabaseService.client.functions.invoke(
            "generate-dream-image",
            options: .init(body: RequestBody(dreamText: dreamText, locale: locale.rawValue, answers: answers))
        )

        guard !response.imageURL.isEmpty else {
            throw Error.emptyURL
        }

        return response.imageURL
    }

    static func generateImageInBackground(
        dreamID: PersistentIdentifier,
        dreamText: String,
        locale: SpeechLocale,
        answers: [String]? = nil,
        modelContainer: ModelContainer,
        onComplete: (@MainActor (String?) -> Void)? = nil
    ) {
        Task { @MainActor in
            do {
                let imageURL = try await generateImage(for: dreamText, locale: locale, answers: answers)
                let context = modelContainer.mainContext
                guard let dream = context.model(for: dreamID) as? Dream else {
                    logger.warning("Dream not found for image update")
                    onComplete?(nil)
                    return
                }
                dream.imageURL = imageURL
                try context.save()
                logger.info("Dream image generated: \(imageURL)")
                onComplete?(imageURL)
            } catch {
                logger.error("Failed to generate dream image: \(error.localizedDescription)")
                onComplete?(nil)
            }
        }
    }

    static func generateInterpretation(for dreamText: String, locale: SpeechLocale, emotions: [DreamEmotion]) async throws -> String {
        guard dreamText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 else {
            throw Error.emptyText
        }

        struct RequestBody: Encodable {
            let dreamText: String
            let locale: String
            let emotions: [String]
        }

        struct ResponseBody: Decodable {
            let interpretation: String
        }

        let response: ResponseBody = try await SupabaseService.client.functions.invoke(
            "generate-dream-interpretation",
            options: .init(body: RequestBody(
                dreamText: dreamText,
                locale: locale.rawValue,
                emotions: emotions.map(\.rawValue)
            ))
        )

        return response.interpretation
    }

    static func generateInterpretationInBackground(
        dreamID: PersistentIdentifier,
        dreamText: String,
        locale: SpeechLocale,
        emotions: [DreamEmotion],
        modelContainer: ModelContainer,
        detailState: DetailDreamState
    ) {
        guard !detailState.isGeneratingInterpretation else { return }
        Task { @MainActor in
            detailState.isGeneratingInterpretation = true
            detailState.interpretationError = nil
            do {
                let interpretation = try await generateInterpretation(for: dreamText, locale: locale, emotions: emotions)
                let context = modelContainer.mainContext
                guard let dream = context.model(for: dreamID) as? Dream else {
                    logger.warning("Dream not found for interpretation update")
                    detailState.isGeneratingInterpretation = false
                    return
                }
                dream.interpretation = interpretation
                try context.save()
                detailState.hasInterpretation = true
                detailState.isGeneratingInterpretation = false
                logger.info("Dream interpretation generated")
            } catch {
                logger.error("Failed to generate interpretation: \(error.localizedDescription)")
                detailState.interpretationError = error.localizedDescription
                detailState.isGeneratingInterpretation = false
            }
        }
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
