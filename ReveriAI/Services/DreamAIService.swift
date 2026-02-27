import Foundation
import Functions
import Supabase
import SwiftData
import os

enum DreamAIService {
    private static let imageSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        return URLSession(configuration: config)
    }()

    enum Error: Swift.Error {
        case networkError(Swift.Error)
        case emptyText
        case emptyTitle
        case emptyURL
        case hallucination
        case rateLimited(retryAfter: Int)
        case textTooLong(count: Int, max: Int)
        case audioTooLarge(bytes: Int, maxBytes: Int)

        var isRateLimited: Bool {
            if case .rateLimited = self { return true }
            return false
        }
    }

    private static let maxDreamTextLength = 10_000
    private static let maxAudioSizeBytes = 25 * 1024 * 1024

    private static let logger = Logger(subsystem: "com.reveri.ai", category: "DreamAI")

    /// Translates `FunctionsError.httpError` from supabase-swift SDK into our domain errors.
    private static func translateError(_ error: Swift.Error) -> Swift.Error {
        guard let functionsError = error as? FunctionsError,
              case let .httpError(code, data) = functionsError else {
            return error
        }
        switch code {
        case 429:
            struct RateLimitBody: Decodable { let retryAfter: Int? }
            let retryAfter = (try? JSONDecoder().decode(RateLimitBody.self, from: data))?.retryAfter ?? 60
            return Error.rateLimited(retryAfter: retryAfter)
        case 413:
            return Error.textTooLong(count: 0, max: maxDreamTextLength)
        default:
            return error
        }
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
        guard dreamText.count <= maxDreamTextLength else {
            throw Error.textTooLong(count: dreamText.count, max: maxDreamTextLength)
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
            throw translateError(error)
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
        guard audioData.count <= maxAudioSizeBytes else {
            throw Error.audioTooLarge(bytes: audioData.count, maxBytes: maxAudioSizeBytes)
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
        if httpResponse.statusCode == 413 {
            throw Error.audioTooLarge(bytes: audioData.count, maxBytes: Self.maxAudioSizeBytes)
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
            var descriptor = FetchDescriptor<Dream>(
                predicate: #Predicate<Dream> { $0.whisperTranscript != nil }
            )
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
                    let transcript = try await AITaskQueue.shared.enqueue {
                        try await transcribeAudio(fileURL: fileURL, locale: locale)
                    }
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
        guard dreamText.count <= maxDreamTextLength else {
            throw Error.textTooLong(count: dreamText.count, max: maxDreamTextLength)
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
            throw translateError(error)
        }

        return response.questions
    }

    struct ImageResult {
        let imageURL: String
        let imagePath: String
    }

    static func generateImage(for dreamText: String, locale: SpeechLocale, answers: [String]? = nil) async throws -> ImageResult {
        guard !dreamText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Error.emptyText
        }
        guard dreamText.count <= maxDreamTextLength else {
            throw Error.textTooLong(count: dreamText.count, max: maxDreamTextLength)
        }

        struct RequestBody: Encodable {
            let dreamText: String
            let locale: String
            let answers: [String]?
        }

        struct ResponseBody: Decodable {
            let imageURL: String
            let imagePath: String
        }

        let response: ResponseBody
        do {
            response = try await SupabaseService.client.functions.invoke(
                "generate-dream-image",
                options: .init(body: RequestBody(dreamText: dreamText, locale: locale.rawValue, answers: answers))
            )
        } catch {
            throw translateError(error)
        }

        guard !response.imageURL.isEmpty else {
            throw Error.emptyURL
        }

        return ImageResult(imageURL: response.imageURL, imagePath: response.imagePath)
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
                let context = modelContainer.mainContext
                let oldImagePath = (context.model(for: dreamID) as? Dream)?.imagePath

                let result = try await AITaskQueue.shared.enqueue {
                    try await generateImage(for: dreamText, locale: locale, answers: answers)
                }

                // Download image to local disk cache
                await downloadImageToDisk(from: result.imageURL, fileName: result.imagePath)

                guard let dream = context.model(for: dreamID) as? Dream else {
                    // Dream deleted while generating — cleanup new file
                    logger.warning("Dream not found for image update, cleaning up")
                    deleteImageFromStorage(imagePath: result.imagePath)
                    deleteLocalImage(imagePath: result.imagePath)
                    onComplete?(nil)
                    return
                }

                dream.imageURL = result.imageURL
                dream.imagePath = result.imagePath
                try context.save()
                logger.info("Dream image generated: \(result.imageURL)")
                onComplete?(result.imageURL)

                // Cleanup old image (local + remote)
                if let oldPath = oldImagePath, oldPath != result.imagePath {
                    deleteLocalImage(imagePath: oldPath)
                    deleteImageFromStorage(imagePath: oldPath)
                }
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
        guard dreamText.count <= maxDreamTextLength else {
            throw Error.textTooLong(count: dreamText.count, max: maxDreamTextLength)
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
            throw translateError(error)
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
                let interpretation = try await AITaskQueue.shared.enqueue {
                    try await generateInterpretation(for: dreamText, locale: locale, emotions: emotions)
                }
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
                let title = try await AITaskQueue.shared.enqueue {
                    try await generateTitle(for: dreamText, locale: locale)
                }
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

    // MARK: - Image Disk Cache

    static let imagesDirectory: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("dream-images")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Downloads image from URL and saves to local disk cache.
    private static func downloadImageToDisk(from urlString: String, fileName: String) async {
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await imageSession.data(from: url)
            let fileURL = imagesDirectory.appendingPathComponent(fileName)
            try data.write(to: fileURL, options: .completeFileProtection)
            logger.info("Cached image to disk: \(fileName)")
        } catch {
            logger.warning("Failed to cache image to disk: \(error.localizedDescription)")
        }
    }

    /// Deletes a locally cached image file.
    static func deleteLocalImage(imagePath: String) {
        let fileURL = imagesDirectory.appendingPathComponent(imagePath)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Deletes image from Supabase Storage (fire-and-forget with retry queue).
    static func deleteImageFromStorage(imagePath: String) {
        Task {
            do {
                struct RequestBody: Encodable { let imagePath: String }
                struct ResponseBody: Decodable { let success: Bool }
                let _: ResponseBody = try await SupabaseService.client.functions.invoke(
                    "delete-dream-image",
                    options: .init(body: RequestBody(imagePath: imagePath))
                )
                logger.info("Deleted image from storage: \(imagePath)")
            } catch {
                logger.warning("Failed to delete image from storage, queued for retry: \(imagePath)")
                addPendingDeletion(imagePath)
            }
        }
    }

    // MARK: - Pending Deletion Retry Queue

    private static let pendingDeletionsKey = "pendingImageDeletions"

    private static func addPendingDeletion(_ imagePath: String) {
        var pending = pendingDeletions
        guard !pending.contains(imagePath) else { return }
        pending.append(imagePath)
        if let data = try? JSONEncoder().encode(pending) {
            UserDefaults.standard.set(data, forKey: pendingDeletionsKey)
        }
    }

    private static var pendingDeletions: [String] {
        guard let data = UserDefaults.standard.data(forKey: pendingDeletionsKey),
              let paths = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return paths
    }

    /// Retries any previously failed storage deletions. Call on app launch.
    static func retryPendingDeletions() {
        let pending = pendingDeletions
        guard !pending.isEmpty else { return }
        logger.info("Retrying \(pending.count) pending image deletions")
        UserDefaults.standard.removeObject(forKey: pendingDeletionsKey)
        for path in pending {
            deleteImageFromStorage(imagePath: path)
        }
    }

    // MARK: - Image Path Migration

    /// Backfills `imagePath` for existing dreams that have `imageURL` but no `imagePath`.
    /// Also downloads images to local disk cache in the background.
    static func migrateImagePaths(modelContainer: ModelContainer) {
        Task { @MainActor in
            let context = modelContainer.mainContext
            var descriptor = FetchDescriptor<Dream>(
                predicate: #Predicate<Dream> { $0.imageURL != nil && $0.imagePath == nil }
            )
            guard let dreams = try? context.fetch(descriptor) else { return }

            var migratedCount = 0
            for dream in dreams {
                guard let urlString = dream.imageURL,
                      dream.imagePath == nil,
                      let url = URL(string: urlString),
                      let fileName = url.lastPathComponent.components(separatedBy: "?").first,
                      fileName.hasSuffix(".png")
                else { continue }

                dream.imagePath = fileName
                migratedCount += 1

                // Background download to disk
                let capturedURL = urlString
                let capturedFileName = fileName
                Task.detached {
                    await downloadImageToDisk(from: capturedURL, fileName: capturedFileName)
                }
            }

            if migratedCount > 0 {
                try? context.save()
                logger.info("Migrated \(migratedCount) dream image paths")
            }
        }
    }
}
