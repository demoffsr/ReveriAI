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
        stableText = ""
        latestText = ""
        transcribedText = ""
        partialText = ""
        accumulatedFinalText = ""
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

        let transcriber = SpeechTranscriber(
            locale: matchedLocale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let bufferConverter = BufferConverter()

        do {
            guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                compatibleWith: [transcriber]
            ) else {
                print("SpeechRecognitionService: no compatible audio format for SpeechAnalyzer")
                await runSFSpeechRecognizer(locale: locale, audioStream: audioStream)
                return
            }

            let (inputStream, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

            // Feed audio buffers in a detached task
            let feedTask = Task.detached { [bufferConverter] in
                for await buffer in audioStream {
                    if Task.isCancelled { break }
                    do {
                        let converted = try bufferConverter.convert(buffer, to: analyzerFormat)
                        inputBuilder.yield(AnalyzerInput(buffer: converted))
                    } catch {
                        print("SpeechRecognitionService: buffer conversion error: \(error)")
                    }
                }
                inputBuilder.finish()
            }

            try await analyzer.start(inputSequence: inputStream)

            // Consume results
            for try await result in transcriber.results {
                if Task.isCancelled { break }

                let text = String(result.text.characters)
                let isFinal = result.isFinal

                await MainActor.run {
                    if isFinal {
                        self.accumulatedFinalText = text
                        self.partialText = ""
                        self.stableText = text
                        self.latestText = ""
                    } else {
                        self.partialText = text
                        self.updateCaptionsFromText(text)
                    }
                    self.transcribedText = self.accumulatedFinalText + self.partialText
                }
            }

            feedTask.cancel()
            try? await analyzer.finalizeAndFinishThroughEndOfInput()

        } catch {
            if !Task.isCancelled {
                print("SpeechRecognitionService: SpeechAnalyzer error: \(error)")
                // Fall back to SFSpeechRecognizer
                await MainActor.run { self.currentEngine = .sfSpeechRecognizer }
                await runSFSpeechRecognizer(locale: locale, audioStream: audioStream)
            }
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

        // Use a relay to fan-out audio buffers to the current recognition request.
        // When the 1-min limit hits, we create a new request and the relay feeds it instead.
        let relay = AudioBufferRelay()

        // Feed audio from the source stream into the relay
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
            case .timeLimitReached:
                // Save partial text as stable before restarting
                await MainActor.run {
                    if !self.partialText.isEmpty {
                        let stitched = self.accumulatedFinalText.isEmpty
                            ? self.partialText
                            : self.accumulatedFinalText + " " + self.partialText
                        self.accumulatedFinalText = stitched
                        self.partialText = ""
                    }
                }
                // Small delay before restarting to avoid hammering
                try? await Task.sleep(for: .milliseconds(300))

            case .audioEnded, .cancelled:
                audioEnded = true
            }
        }

        feedTask.cancel()
    }

    private enum SFSessionResult {
        case timeLimitReached
        case audioEnded
        case cancelled
    }

    /// Runs a single SFSpeechRecognizer session until it finishes or hits the ~1-min limit.
    private func runSingleSFSession(
        recognizer: SFSpeechRecognizer,
        relay: AudioBufferRelay
    ) async -> SFSessionResult {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let (resultStream, resultContinuation) = AsyncStream<SFSpeechRecognitionResult?>.makeStream()
        var endedDueToLimit = false

        let recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                resultContinuation.yield(result)
                if result.isFinal {
                    resultContinuation.finish()
                }
            }
            if let error {
                // Error code 1101 = "Retry" / time limit reached
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101 {
                    endedDueToLimit = true
                }
                resultContinuation.finish()
            }
        }

        // Subscribe to the relay and feed buffers to this session's request
        let (bufferStream, token) = relay.subscribe()
        let relayTask = Task.detached {
            for await buffer in bufferStream {
                if Task.isCancelled { break }
                request.append(buffer)
            }
            request.endAudio()
        }

        let baseText = self.accumulatedFinalText

        // Consume results
        for await result in resultStream {
            guard let result, !Task.isCancelled else { break }

            let sessionText = result.bestTranscription.formattedString

            await MainActor.run {
                if result.isFinal {
                    let finalText = baseText.isEmpty ? sessionText : baseText + " " + sessionText
                    self.accumulatedFinalText = finalText
                    self.partialText = ""
                    self.stableText = finalText
                    self.latestText = ""
                } else {
                    let fullText = baseText.isEmpty ? sessionText : baseText + " " + sessionText
                    self.partialText = sessionText
                    self.updateCaptionsFromText(fullText)
                }
                self.transcribedText = self.accumulatedFinalText +
                    (self.partialText.isEmpty ? "" : " " + self.partialText)
            }
        }

        recognitionTask.cancel()
        relay.unsubscribe(token)
        relayTask.cancel()

        if Task.isCancelled { return .cancelled }
        if endedDueToLimit { return .timeLimitReached }
        return .audioEnded
    }

    // MARK: - Live Captions Helpers

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
