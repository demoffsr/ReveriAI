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
        case hallucination
        case rateLimited(retryAfter: Int)

        var isRateLimited: Bool {
            if case .rateLimited = self { return true }
            return false
        }
    }

    private static let logger = Logger(subsystem: "com.reveri.ai", category: "DreamAI")

    /// Translates `FunctionsError.httpError(code: 429)` from supabase-swift SDK into our `.rateLimited` error.
    private static func translateRateLimitError(_ error: Swift.Error) -> Swift.Error {
        guard let functionsError = error as? FunctionsError,
              case let .httpError(code, data) = functionsError,
              code == 429 else {
            return error
        }
        struct RateLimitBody: Decodable { let retryAfter: Int? }
        let retryAfter = (try? JSONDecoder().decode(RateLimitBody.self, from: data))?.retryAfter ?? 60
        return Error.rateLimited(retryAfter: retryAfter)
    }

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

        let response: ResponseBody
        do {
            response = try await SupabaseService.client.functions.invoke(
                "generate-dream-title",
                options: .init(body: RequestBody(dreamText: dreamText, locale: locale.rawValue))
            )
        } catch {
            throw translateRateLimitError(error)
        }

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
        let accessToken: String
        do {
            accessToken = try await SupabaseService.client.auth.session.accessToken
        } catch {
            throw Error.networkError(
                NSError(domain: "Auth", code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "Not authenticated — sign in failed or no network on first launch"])
            )
        }
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
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
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.networkError(NSError(domain: "WhisperAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
        }
        if httpResponse.statusCode == 429 {
            let retryAfter = Int(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60
            throw Error.rateLimited(retryAfter: retryAfter)
        }
        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw Error.networkError(NSError(domain: "WhisperAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText]))
        }

        struct TranscriptResponse: Decodable {
            let transcript: String
        }

        let decoded = try JSONDecoder().decode(TranscriptResponse.self, from: data)
        guard !decoded.transcript.isEmpty else {
            throw Error.emptyText
        }

        if isHallucination(decoded.transcript) {
            logger.warning("🚨 Whisper hallucination detected: \(decoded.transcript.prefix(100))")
            throw Error.hallucination
        }

        return decoded.transcript
    }

    // MARK: - Whisper Hallucination Detection

    /// Detects common Whisper hallucination patterns:
    /// - Repetitive phrases (same phrase 3+ times = >50% of text)
    /// - Known hallucination phrases in any language
    private static func isHallucination(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Known Whisper hallucination phrases (case-insensitive)
        let knownHallucinations = [
            "подпишитесь на канал",
            "звук сообщения",
            "спасибо за просмотр",
            "спасибо за внимание",
            "thanks for watching",
            "subscribe to the channel",
            "thank you for watching",
            "like and subscribe",
            "please subscribe",
            "music playing",
            "subtitles by",
        ]

        let lower = trimmed.lowercased()
        for phrase in knownHallucinations {
            if lower.contains(phrase) {
                return true
            }
        }

        // Repetition detection: split into sentences, check if any repeats 3+ times
        let sentences = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.count > 3 }

        guard sentences.count >= 3 else { return false }

        var freq: [String: Int] = [:]
        for s in sentences { freq[s, default: 0] += 1 }
        if let maxCount = freq.values.max(), maxCount >= 3 {
            let repetitionRatio = Double(maxCount) / Double(sentences.count)
            if repetitionRatio > 0.4 {
                return true
            }
        }

        // Word-level repetition: if >60% of words are from one 2-3 word phrase repeating
        let words = lower.split(separator: " ").map(String.init)
        if words.count >= 6 {
            var bigramFreq: [String: Int] = [:]
            for i in 0..<(words.count - 1) {
                let bigram = "\(words[i]) \(words[i+1])"
                bigramFreq[bigram, default: 0] += 1
            }
            if let (_, maxCount) = bigramFreq.max(by: { $0.value < $1.value }),
               maxCount >= 4, Double(maxCount * 2) / Double(words.count) > 0.4 {
                return true
            }
        }

        return false
    }

    private static let recordingsDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
    }()

    // MARK: - One-time Hallucination Cleanup

    /// Scans all dreams for hallucinated Whisper transcripts, reverts to original, re-triggers transcription.
    static func cleanupHallucinatedTranscripts(modelContainer: ModelContainer) {
        Task { @MainActor in
            let context = modelContainer.mainContext
            let descriptor = FetchDescriptor<Dream>()
            guard let dreams = try? context.fetch(descriptor) else { return }

            var fixedCount = 0
            for dream in dreams {
                guard let whisper = dream.whisperTranscript,
                      isHallucination(whisper) else { continue }

                logger.warning("🧹 Hallucination cleanup: dream \(dream.id) — \(whisper.prefix(60))")

                // Revert text to original
                if let original = dream.originalTranscript {
                    dream.text = original
                }
                dream.whisperTranscript = nil
                fixedCount += 1

                // Re-trigger Whisper transcription if audio file exists
                if let audioFileName = dream.audioFilePath {
                    let locale = SpeechLocale(rawValue: UserDefaults.standard.string(forKey: "speechRecognitionLocale") ?? "") ?? .russian
                    transcribeAudioInBackground(
                        dreamID: dream.persistentModelID,
                        audioFileName: audioFileName,
                        locale: locale,
                        modelContainer: modelContainer
                    )
                }
            }

            if fixedCount > 0 {
                try? context.save()
                logger.info("🧹 Hallucination cleanup: fixed \(fixedCount) dream(s)")
            }
        }
    }

    private static let maxWhisperRetries = 2

    static func transcribeAudioInBackground(
        dreamID: PersistentIdentifier,
        audioFileName: String,
        locale: SpeechLocale,
        modelContainer: ModelContainer
    ) {
        Task { @MainActor in
            let fileURL = recordingsDirectory.appendingPathComponent(audioFileName)
            logger.info("📂 Whisper: looking for file at \(fileURL.path)")
            let exists = FileManager.default.fileExists(atPath: fileURL.path)
            logger.info("📂 Whisper: file exists = \(exists)")
            guard exists else {
                logger.error("Audio file not found: \(audioFileName)")
                return
            }

            let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
            logger.info("📂 Whisper: file size = \(fileSize) bytes")

            var lastError: Swift.Error?
            for attempt in 1...maxWhisperRetries {
                do {
                    logger.info("🌐 Whisper: attempt \(attempt)/\(maxWhisperRetries)...")
                    let transcript = try await transcribeAudio(fileURL: fileURL, locale: locale)
                    logger.info("✅ Whisper: got transcript (\(transcript.count) chars): \(transcript.prefix(80))")
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
                    return // success — exit
                } catch Error.hallucination {
                    logger.warning("🚨 Whisper hallucination on attempt \(attempt)")
                    lastError = Error.hallucination
                    if attempt < maxWhisperRetries {
                        // Brief delay before retry
                        try? await Task.sleep(for: .seconds(1))
                    }
                } catch {
                    logger.error("Whisper transcription failed: \(error.localizedDescription)")
                    lastError = error
                    break // non-hallucination errors — don't retry
                }
            }

            // All retries exhausted or non-retryable error — keep original transcript
            logger.warning("Whisper failed after retries, keeping original transcript")
            let context = modelContainer.mainContext
            if let dream = context.model(for: dreamID) as? Dream {
                if dream.text.isEmpty, let original = dream.originalTranscript {
                    dream.text = original
                    try? context.save()
                }
                // Generate title from whatever text we have
                if dream.title.isEmpty, !dream.text.isEmpty {
                    generateTitleInBackground(
                        dreamID: dreamID,
                        dreamText: dream.text,
                        locale: locale,
                        modelContainer: modelContainer
                    )
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

        let response: ResponseBody
        do {
            response = try await SupabaseService.client.functions.invoke(
                "generate-dream-questions",
                options: .init(body: RequestBody(dreamText: dreamText, locale: locale.rawValue))
            )
        } catch {
            throw translateRateLimitError(error)
        }

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

        let response: ResponseBody
        do {
            response = try await SupabaseService.client.functions.invoke(
                "generate-dream-image",
                options: .init(body: RequestBody(dreamText: dreamText, locale: locale.rawValue, answers: answers))
            )
        } catch {
            throw translateRateLimitError(error)
        }

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
        detailState: DetailDreamState? = nil,
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
            } catch Error.rateLimited {
                logger.warning("Image generation rate limited")
                detailState?.showRateLimitToast = true
                onComplete?(nil)
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

        let response: ResponseBody
        do {
            response = try await SupabaseService.client.functions.invoke(
                "generate-dream-interpretation",
                options: .init(body: RequestBody(
                    dreamText: dreamText,
                    locale: locale.rawValue,
                    emotions: emotions.map(\.rawValue)
                ))
            )
        } catch {
            throw translateRateLimitError(error)
        }

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
            } catch Error.rateLimited {
                logger.warning("Interpretation rate limited")
                detailState.interpretationError = String(localized: "error.rateLimited")
                detailState.isGeneratingInterpretation = false
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
