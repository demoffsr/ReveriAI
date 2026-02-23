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

    /// Pre-warm the Edge Function to avoid cold start delay.
    static func warmUp() {
        Task {
            do {
                struct WarmupBody: Encodable { let warmup = true }
                let _: [String: Bool] = try await SupabaseService.client.functions.invoke(
                    "generate-dream-title",
                    options: .init(body: WarmupBody())
                )
                logger.debug("Edge Function warmed up")
            } catch {
                logger.debug("Warmup ping failed (non-critical): \(error.localizedDescription)")
            }
        }
    }

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

    static func transcribeAudio(fileURL: URL, locale: SpeechLocale) async throws -> String {
        let audioData = try Data(contentsOf: fileURL)
        guard !audioData.isEmpty else {
            throw Error.emptyText
        }

        let boundary = UUID().uuidString
        let url = URL(string: "\(SupabaseConfig.projectURL)/functions/v1/transcribe-audio")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // File field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        // Locale field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"locale\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(locale.rawValue)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        // Dedicated session with 120s timeout for long recordings
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw Error.networkError(NSError(domain: "WhisperAPI", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: errorText]))
        }

        struct TranscriptResponse: Decodable {
            let transcript: String
        }

        let decoded = try JSONDecoder().decode(TranscriptResponse.self, from: data)
        guard !decoded.transcript.isEmpty else {
            throw Error.emptyText
        }

        return decoded.transcript
    }

    private static let recordingsDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
    }()

    static func transcribeAudioInBackground(
        dreamID: PersistentIdentifier,
        audioFileName: String,
        locale: SpeechLocale,
        modelContainer: ModelContainer
    ) {
        Task { @MainActor in
            let fileURL = recordingsDirectory.appendingPathComponent(audioFileName)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                logger.error("Audio file not found: \(audioFileName)")
                return
            }

            do {
                let transcript = try await transcribeAudio(fileURL: fileURL, locale: locale)
                let context = modelContainer.mainContext
                guard let dream = context.model(for: dreamID) as? Dream else {
                    logger.warning("Dream not found for Whisper update")
                    return
                }
                dream.whisperTranscript = transcript
                dream.text = transcript
                try context.save()
                logger.info("Whisper transcription saved (\(transcript.count) chars)")

                // Generate title from high-quality Whisper text
                if dream.title.isEmpty {
                    generateTitleInBackground(
                        dreamID: dreamID,
                        dreamText: transcript,
                        locale: locale,
                        modelContainer: modelContainer
                    )
                }
            } catch {
                logger.error("Whisper transcription failed: \(error.localizedDescription)")
                // Fallback: ensure dream.text has the original transcript
                let context = modelContainer.mainContext
                if let dream = context.model(for: dreamID) as? Dream,
                   dream.text.isEmpty,
                   let original = dream.originalTranscript {
                    dream.text = original
                    try? context.save()
                }
            }
        }
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
