@preconcurrency import AVFoundation
import Speech

@Observable
final class SpeechRecognitionService {

    // MARK: - Public Types

    enum SpeechEngine: String {
        case speechAnalyzer
        case sfSpeechRecognizer
        case whisperKit // TODO: WhisperKit integration
        case none
    }

    // MARK: - Punctuation Constants

    private static let fillers: Set<String> = [
        "а", "ну", "и", "но", "да", "так", "вот", "ведь", "же",
        "ой", "эй", "ну-ка", "слушай", "слушайте", "скажи", "скажите",
        "well", "so", "and", "but", "oh", "hey",
    ]

    private static let questionWords: Set<String> = [
        "почему", "зачем", "откуда", "куда", "сколько",
        "кто", "кого", "кому", "кем",
        "что", "чего", "чему", "чем",
        "где", "когда",
        "какой", "какая", "какое", "какие", "каким", "каких",
        "чей", "чья", "чьё", "чьи",
        "why", "how", "what", "where", "when", "who", "which",
        "do", "does", "did", "is", "are", "was", "were",
        "will", "can", "could", "should", "would",
    ]

    // MARK: - Public State

    /// All accumulated final text + current partial text.
    private(set) var transcribedText: String = ""
    /// Current volatile/partial text from the active engine.
    private(set) var partialText: String = ""
    /// Confirmed words so far (for live captions UI).
    private(set) var stableText: String = ""
    /// In-progress word for gradient styling (for live captions UI).
    private(set) var latestText: String = ""
    private(set) var isTranscribing: Bool = false
    private(set) var currentEngine: SpeechEngine = .none

    // MARK: - Private State

    private var transcriptionTask: Task<Void, Never>?
    /// Text accumulated from finalized results across restarts.
    private var accumulatedFinalText: String = ""

    // MARK: - Public API

    /// Start transcription using the device's current locale.
    func startTranscription(audioStream: AsyncStream<AVAudioPCMBuffer>) {
        startTranscription(locale: Locale.current, audioStream: audioStream)
    }

    /// Start transcription with given locale. Auto-selects best available engine.
    func startTranscription(locale: Locale, audioStream: AsyncStream<AVAudioPCMBuffer>) {
        stopTranscription()
        resetTranscription()

        transcriptionTask = Task {
            let engine = await selectEngine(for: locale)
            print("🎤 SpeechRecognitionService: engine=\(engine.rawValue) locale=\(locale.identifier)")

            await MainActor.run {
                self.currentEngine = engine
                self.isTranscribing = engine != .none
            }

            switch engine {
            case .speechAnalyzer:
                await runSpeechAnalyzer(locale: locale, audioStream: audioStream)
            case .sfSpeechRecognizer:
                await runSFSpeechRecognizer(locale: locale, audioStream: audioStream)
            case .whisperKit:
                // TODO: WhisperKit implementation
                break
            case .none:
                print("SpeechRecognitionService: no engine available for \(locale.identifier)")
            }

            await MainActor.run {
                self.isTranscribing = false
                self.currentEngine = .none
            }
        }
    }

    /// Stop transcription and return final text.
    @discardableResult
    func stopTranscription() -> String {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        let result = accumulatedFinalText + partialText
        return result.isEmpty ? transcribedText : result
    }

    /// Reset all text state.
    func resetTranscription() {
        #if DEBUG
        if !accumulatedFinalText.isEmpty {
            print("🔴 resetTranscription() called while accumulated=[\(accumulatedFinalText)]")
            Thread.callStackSymbols.prefix(10).forEach { print("   \($0)") }
        }
        #endif
        stableText = ""
        latestText = ""
        transcribedText = ""
        partialText = ""
        accumulatedFinalText = ""
    }

    // MARK: - Pause Support

    /// Commits current volatile text into accumulatedFinalText so it's preserved on resume.
    func pauseTranscription() {
        guard !partialText.isEmpty else { return }
        let punctuated = Self.punctuateSegment(partialText)
        let separator = accumulatedFinalText.isEmpty ? "" : " "
        accumulatedFinalText += separator + punctuated
        stableText = accumulatedFinalText
        partialText = ""
        latestText = ""
        transcribedText = accumulatedFinalText
    }

    // MARK: - Engine Selection

    private func selectEngine(for locale: Locale) async -> SpeechEngine {
        // Tier 1: SpeechAnalyzer / SpeechTranscriber (iOS 26+)
        if await isSpeechTranscriberAvailable(for: locale) {
            return .speechAnalyzer
        }

        // Tier 2: SFSpeechRecognizer
        if isSFSpeechRecognizerAvailable(for: locale) {
            return .sfSpeechRecognizer
        }

        // Tier 3: WhisperKit — not yet implemented
        return .none
    }

    // MARK: - Tier 1: SpeechAnalyzer / SpeechTranscriber

    private func isSpeechTranscriberAvailable(for locale: Locale) async -> Bool {
        let supported = await SpeechTranscriber.supportedLocales
        let localeId = locale.identifier
        // Check exact match or language-only match
        if supported.contains(where: { $0.identifier == localeId }) {
            return true
        }
        // Try language-only fallback (e.g. "ru" for "ru_RU")
        let language = locale.language.languageCode?.identifier ?? ""
        return supported.contains(where: {
            $0.language.languageCode?.identifier == language
        })
    }

    private enum SASessionResult {
        case sessionEnded
        case audioEnded
        case cancelled
    }

    private func runSpeechAnalyzer(locale: Locale, audioStream: AsyncStream<AVAudioPCMBuffer>) async {
        // Find the best matching supported locale
        let supported = await SpeechTranscriber.supportedLocales
        let localeId = locale.identifier
        let language = locale.language.languageCode?.identifier ?? ""

        let matchedLocale = supported.first(where: { $0.identifier == localeId })
            ?? supported.first(where: { $0.language.languageCode?.identifier == language })

        guard let matchedLocale else {
            print("SpeechRecognitionService: SpeechTranscriber locale not found, falling back")
            await runSFSpeechRecognizer(locale: locale, audioStream: audioStream)
            return
        }

        let bufferConverter = BufferConverter()

        // Get analyzer format once (shared across sessions)
        let testTranscriber = SpeechTranscriber(
            locale: matchedLocale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [testTranscriber]
        ) else {
            print("SpeechRecognitionService: no compatible audio format for SpeechAnalyzer")
            await runSFSpeechRecognizer(locale: locale, audioStream: audioStream)
            return
        }

        // Relay fans out audio buffers to each session (same pattern as SFSpeechRecognizer)
        let relay = AudioBufferRelay()
        let mainFeedTask = Task.detached {
            for await buffer in audioStream {
                if Task.isCancelled { break }
                relay.send(buffer)
            }
            relay.finish()
        }

        var audioEnded = false

        while !audioEnded && !Task.isCancelled {
            let sessionResult = await runSingleSpeechAnalyzerSession(
                locale: matchedLocale,
                analyzerFormat: analyzerFormat,
                bufferConverter: bufferConverter,
                relay: relay
            )

            switch sessionResult {
            case .sessionEnded:
                // SpeechTranscriber ended the segment — commit partial and restart
                #if DEBUG
                print("SpeechAnalyzer session ended, restarting...")
                #endif
                await MainActor.run { self.pauseTranscription() }
                try? await Task.sleep(for: .milliseconds(200))

            case .audioEnded, .cancelled:
                audioEnded = true
            }
        }

        mainFeedTask.cancel()
    }

    /// Runs a single SpeechAnalyzer session until transcriber.results ends or an error occurs.
    private func runSingleSpeechAnalyzerSession(
        locale: Locale,
        analyzerFormat: AVAudioFormat,
        bufferConverter: BufferConverter,
        relay: AudioBufferRelay
    ) async -> SASessionResult {
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let (inputStream, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

        // Subscribe to relay for this session
        let (bufferStream, token) = relay.subscribe()
        let sessionFeedTask = Task.detached { [bufferConverter] in
            for await buffer in bufferStream {
                if Task.isCancelled { break }
                do {
                    let converted = try bufferConverter.convert(buffer, to: analyzerFormat)
                    inputBuilder.yield(AnalyzerInput(buffer: converted))
                } catch {
                    #if DEBUG
                    print("SpeechRecognitionService: buffer conversion error: \(error)")
                    #endif
                }
            }
            inputBuilder.finish()
        }

        do {
            try await analyzer.start(inputSequence: inputStream)

            // Consume results until stream ends
            for try await result in transcriber.results {
                if Task.isCancelled { break }

                let text = String(result.text.characters)
                let isFinal = result.isFinal

                await MainActor.run {
                    if isFinal {
                        guard !text.isEmpty else { return }

                        // ALWAYS APPEND — never replace, text can never be lost
                        let punctuated = Self.punctuateSegment(text)
                        if self.accumulatedFinalText.isEmpty {
                            self.accumulatedFinalText = punctuated
                        } else {
                            self.accumulatedFinalText += " " + punctuated
                        }
                        self.partialText = ""
                        self.stableText = self.accumulatedFinalText
                        self.latestText = ""
                        self.transcribedText = self.accumulatedFinalText
                        #if DEBUG
                        print("🟢 FINAL → transcribed=[\(self.transcribedText)]")
                        #endif
                    } else {
                        guard !text.isEmpty else { return }

                        self.partialText = text
                        let fullText: String
                        if self.accumulatedFinalText.isEmpty {
                            fullText = text
                        } else {
                            fullText = self.accumulatedFinalText + " " + text
                        }
                        self.updateCaptionsFromText(fullText)
                        self.transcribedText = fullText
                        #if DEBUG
                        print("🔵 VOLATILE → transcribed=[\(self.transcribedText)]")
                        #endif
                    }
                }
            }

            #if DEBUG
            print("⏹️ transcriber.results stream ended, accumulated: [\(await MainActor.run { self.accumulatedFinalText })]")
            #endif

            // Clean up BEFORE finalize to avoid deadlock
            // (finalize waits for input to end, but feed is still running)
            relay.unsubscribe(token)
            sessionFeedTask.cancel()
            try? await analyzer.finalizeAndFinishThroughEndOfInput()

            if Task.isCancelled { return .cancelled }
            return .sessionEnded

        } catch {
            relay.unsubscribe(token)
            sessionFeedTask.cancel()
            if Task.isCancelled { return .cancelled }
            #if DEBUG
            print("❌ SpeechAnalyzer session error: \(error)")
            #endif
            return .sessionEnded
        }
    }

    // MARK: - Tier 2: SFSpeechRecognizer

    private func isSFSpeechRecognizerAvailable(for locale: Locale) -> Bool {
        let recognizer = SFSpeechRecognizer(locale: locale)
        return recognizer?.isAvailable ?? false
    }

    private func runSFSpeechRecognizer(locale: Locale, audioStream: AsyncStream<AVAudioPCMBuffer>) async {
        let authorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard authorized else {
            print("SpeechRecognitionService: speech recognition not authorized")
            return
        }

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            print("SpeechRecognitionService: SFSpeechRecognizer not available for \(locale.identifier)")
            return
        }

        await MainActor.run {
            self.currentEngine = .sfSpeechRecognizer
            self.isTranscribing = true
        }

        // Relay fans out audio buffers to each session (allows restart on pause/time limit)
        let relay = AudioBufferRelay()

        let feedTask = Task.detached {
            for await buffer in audioStream {
                if Task.isCancelled { break }
                relay.send(buffer)
            }
            relay.finish()
        }

        var audioEnded = false

        while !audioEnded && !Task.isCancelled {
            let sessionResult = await runSingleSFSession(recognizer: recognizer, relay: relay)

            switch sessionResult {
            case .sessionEnded:
                // SF session ended (speech pause or time limit) — commit partial and restart
                print("🔄 SF session ended, restarting... relay.isActive=\(relay.isActive)")
                await MainActor.run { self.pauseTranscription() }
                guard relay.isActive else {
                    audioEnded = true
                    break
                }
                try? await Task.sleep(for: .milliseconds(300))

            case .audioEnded:
                audioEnded = true

            case .cancelled:
                audioEnded = true
            }
        }

        feedTask.cancel()
    }

    private enum SFSessionResult {
        case sessionEnded  // speech pause or time limit — can restart
        case audioEnded    // relay finished — recording stopped
        case cancelled
    }

    /// Runs a single SFSpeechRecognizer session until it finishes or hits the ~1-min limit.
    private func runSingleSFSession(
        recognizer: SFSpeechRecognizer,
        relay: AudioBufferRelay
    ) async -> SFSessionResult {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let (resultStream, resultContinuation) = AsyncStream<SFSpeechRecognitionResult?>.makeStream()

        let recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                resultContinuation.yield(result)
                if result.isFinal {
                    resultContinuation.finish()
                }
            }
            if error != nil {
                resultContinuation.finish()
            }
        }

        // Subscribe to relay for this session
        let (bufferStream, token) = relay.subscribe()
        let relayTask = Task.detached {
            for await buffer in bufferStream {
                if Task.isCancelled { break }
                request.append(buffer)
            }
            request.endAudio()
        }

        var baseText = self.accumulatedFinalText
        var lastSessionText = ""

        // Consume results — SF gives CUMULATIVE text within an utterance,
        // but silently resets when it detects a new utterance (no isFinal sent!)
        for await result in resultStream {
            guard let result, !Task.isCancelled else { break }

            let sessionText = result.bestTranscription.formattedString
            guard !sessionText.isEmpty else { continue }

            // Detect SF silent reset: text changed in a way that's NOT a continuation
            if !lastSessionText.isEmpty
                && !sessionText.hasPrefix(lastSessionText)
                && !lastSessionText.hasPrefix(sessionText)
            {
                // Check first character (case-insensitive) — different = new utterance
                // Same first char (Но/Ну) = SF correction within same utterance
                let firstCharSame: Bool
                if let old = lastSessionText.first, let new = sessionText.first {
                    firstCharSame = old.lowercased() == new.lowercased()
                } else {
                    firstCharSame = true
                }
                let textShrunk = sessionText.count * 2 < lastSessionText.count

                if !firstCharSame || textShrunk {
                    // SF started new utterance — commit previous text with punctuation
                    await MainActor.run {
                        let punctuated = Self.punctuateSegment(lastSessionText)
                        if baseText.isEmpty {
                            baseText = punctuated
                        } else {
                            let next = Self.endsWithSentencePunctuation(baseText) ? punctuated : Self.lowercaseFirst(punctuated)
                            baseText += " " + next
                        }
                        self.accumulatedFinalText = baseText
                        self.partialText = ""
                        print("🟡 SF auto-commit → accumulated=[\(baseText)]")
                    }
                }
            }
            lastSessionText = sessionText

            await MainActor.run {
                if result.isFinal {
                    // Punctuate the finalized session text
                    let punctuated = Self.punctuateSegment(sessionText)
                    let finalText: String
                    if baseText.isEmpty {
                        finalText = punctuated
                    } else {
                        let next = Self.endsWithSentencePunctuation(baseText) ? punctuated : Self.lowercaseFirst(punctuated)
                        finalText = baseText + " " + next
                    }
                    self.accumulatedFinalText = finalText
                    baseText = finalText
                    lastSessionText = ""
                    self.partialText = ""
                    self.stableText = finalText
                    self.latestText = ""
                    self.transcribedText = finalText
                    print("🟢 SF FINAL → transcribed=[\(finalText)]")
                } else {
                    // Volatile — no punctuation, live captions only
                    let fullText: String
                    if baseText.isEmpty {
                        fullText = sessionText
                    } else {
                        let next = Self.endsWithSentencePunctuation(baseText) ? sessionText : Self.lowercaseFirst(sessionText)
                        fullText = baseText + " " + next
                    }
                    self.partialText = sessionText
                    self.updateCaptionsFromText(fullText)
                    self.transcribedText = fullText
                }
            }
        }

        recognitionTask.cancel()
        relay.unsubscribe(token)
        relayTask.cancel()

        if Task.isCancelled { return .cancelled }
        // If relay is still active, recording continues — this was just a speech pause
        if relay.isActive { return .sessionEnded }
        return .audioEnded
    }

    // MARK: - Live Captions Helpers

    /// Lowercase the first character of a string (for natural flow after auto-commit).
    private static func lowercaseFirst(_ text: String) -> String {
        guard let first = text.first, first.isUppercase else { return text }
        return text.prefix(1).lowercased() + text.dropFirst()
    }

    /// Whether the next segment should keep its capital letter (previous text ends with sentence punctuation).
    private static func endsWithSentencePunctuation(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return ".?!".contains(last)
    }

    /// Adds ending punctuation to a committed speech segment.
    /// Skips Russian filler words to find the first meaningful word, then checks for question patterns.
    /// No-op if text already ends with punctuation (e.g. English with addsPunctuation).
    private static func punctuateSegment(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return text }

        // Already has ending punctuation (English addsPunctuation, etc.)
        if let last = trimmed.last, ".?!…".contains(last) {
            return text
        }

        let lower = trimmed.lowercased()
        let words = lower.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return text + "." }

        // Question particles anywhere in text — always questions
        if lower.contains(" ли ") || lower.hasSuffix(" ли") { return text + "?" }
        if words.contains("неужели") || words.contains("разве") { return text + "?" }

        // Skip filler words to find the first significant word
        let fillers = Self.fillers
        guard let firstSignificant = words.drop(while: { fillers.contains($0) }).first else {
            return text + "."
        }

        // Question words — match as first significant word
        let questionWords = Self.questionWords

        if questionWords.contains(firstSignificant) {
            return text + "?"
        }

        return text + "."
    }

    /// Split text into stableText (all except last word) and latestText (last word) for gradient styling.
    private func updateCaptionsFromText(_ fullText: String) {
        if let lastSpace = fullText.lastIndex(of: " ") {
            self.stableText = String(fullText[...lastSpace])
            self.latestText = String(fullText[fullText.index(after: lastSpace)...])
        } else {
            self.stableText = ""
            self.latestText = fullText
        }
    }
}

// MARK: - BufferConverter

private final class BufferConverter: @unchecked Sendable {
    private nonisolated(unsafe) var converter: AVAudioConverter?

    nonisolated func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        guard inputFormat != format else { return buffer }

        if converter == nil || converter?.inputFormat != inputFormat || converter?.outputFormat != format {
            converter = AVAudioConverter(from: inputFormat, to: format)
            converter?.primeMethod = .none
        }
        guard let converter else { throw ConversionError.noConverter }

        let ratio = format.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw ConversionError.bufferCreationFailed
        }

        var done = false
        let status = converter.convert(to: output, error: nil) { _, statusPtr in
            defer { done = true }
            statusPtr.pointee = done ? .noDataNow : .haveData
            return done ? nil : buffer
        }
        guard status != .error else { throw ConversionError.conversionFailed }
        return output
    }

    enum ConversionError: Error {
        case noConverter, bufferCreationFailed, conversionFailed
    }
}

// MARK: - AudioBufferRelay

/// Fans out audio buffers to subscribers (for SFSpeechRecognizer restart pattern).
/// When the 1-min limit hits, the old subscription is unsubscribed and a new one takes over,
/// while the source stream keeps feeding into `send()`.
private final class AudioBufferRelay: @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var nextId: UInt64 = 0
    private nonisolated(unsafe) var subscribers: [UInt64: AsyncStream<AVAudioPCMBuffer>.Continuation] = [:]
    private nonisolated(unsafe) var isFinished = false

    struct SubscriptionToken: Sendable {
        fileprivate let id: UInt64
    }

    /// Whether the relay is still accepting buffers (recording still active).
    nonisolated var isActive: Bool {
        lock.lock()
        let active = !isFinished
        lock.unlock()
        return active
    }

    nonisolated func send(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let subs = subscribers
        lock.unlock()
        for (_, continuation) in subs {
            continuation.yield(buffer)
        }
    }

    nonisolated func finish() {
        lock.lock()
        isFinished = true
        let subs = subscribers
        subscribers.removeAll()
        lock.unlock()
        for (_, continuation) in subs {
            continuation.finish()
        }
    }

    nonisolated func subscribe() -> (stream: AsyncStream<AVAudioPCMBuffer>, token: SubscriptionToken) {
        let (stream, continuation) = AsyncStream<AVAudioPCMBuffer>.makeStream()
        lock.lock()
        let id = nextId
        nextId += 1
        if isFinished {
            lock.unlock()
            continuation.finish()
        } else {
            subscribers[id] = continuation
            lock.unlock()
        }
        return (stream, SubscriptionToken(id: id))
    }

    nonisolated func unsubscribe(_ token: SubscriptionToken) {
        lock.lock()
        let continuation = subscribers.removeValue(forKey: token.id)
        lock.unlock()
        continuation?.finish()
    }
}
