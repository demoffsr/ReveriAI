@preconcurrency import AVFoundation
import Speech

@Observable
final class SpeechRecognitionService {
    private(set) var transcribedText: String = ""
    private(set) var stableText: String = ""
    private(set) var latestText: String = ""
    private(set) var isTranscribing = false

    private var sfRecognitionTask: SFSpeechRecognitionTask?
    private var sfRequest: SFSpeechAudioBufferRecognitionRequest?
    private var transcriptionTask: Task<Void, Never>?

    /// Begin transcribing audio from the given buffer stream.
    /// Uses SFSpeechRecognizer with the device's Siri/dictation language.
    func startTranscription(audioStream: AsyncStream<AVAudioPCMBuffer>) {
        stopTranscription()
        resetTranscription()

        transcriptionTask = Task {
            await self.runRecognition(audioStream: audioStream)

            await MainActor.run {
                self.isTranscribing = false
            }
        }
    }

    func stopTranscription() {
        sfRequest?.endAudio()

        let task = transcriptionTask
        transcriptionTask = nil
        Task {
            try? await Task.sleep(for: .seconds(1))
            task?.cancel()
        }
    }

    func resetTranscription() {
        stableText = ""
        latestText = ""
        transcribedText = ""
    }

    // MARK: - SFSpeechRecognizer

    private func runRecognition(audioStream: AsyncStream<AVAudioPCMBuffer>) async {
        let authorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard authorized else {
            print("SpeechRecognitionService: speech recognition not authorized")
            return
        }

        // No explicit locale → uses device's Siri/dictation language
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            print("SpeechRecognitionService: SFSpeechRecognizer not available")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        await MainActor.run {
            self.sfRequest = request
            self.isTranscribing = true
        }

        // Bridge callback API to AsyncStream
        let (resultStream, resultContinuation) = AsyncStream<SFSpeechRecognitionResult>.makeStream()

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

        await MainActor.run { self.sfRecognitionTask = recognitionTask }

        // Feed audio buffers to the recognizer
        let feedTask = Task.detached {
            for await buffer in audioStream {
                request.append(buffer)
            }
            request.endAudio()
        }

        // Consume results
        for await result in resultStream {
            await MainActor.run {
                let fullText = result.bestTranscription.formattedString
                if result.isFinal {
                    self.stableText = fullText
                    self.latestText = ""
                } else {
                    // Last word gets the gradient, rest is stable
                    if let lastSpace = fullText.lastIndex(of: " ") {
                        self.stableText = String(fullText[...lastSpace])
                        self.latestText = String(fullText[fullText.index(after: lastSpace)...])
                    } else {
                        self.stableText = ""
                        self.latestText = fullText
                    }
                }
                self.transcribedText = fullText
            }
        }

        feedTask.cancel()

        await MainActor.run {
            self.sfRecognitionTask = nil
            self.sfRequest = nil
        }
    }
}
