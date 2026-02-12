import AVFoundation
import Foundation

@Observable
final class AudioRecorder: NSObject, AVAudioPlayerDelegate {
    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var currentLevel: Float = 0
    private(set) var recordedFileURL: URL?

    // Playback state
    private(set) var isPlaying = false
    private(set) var playbackCurrentTime: TimeInterval = 0
    private(set) var playbackDuration: TimeInterval = 0

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var audioBufferContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimerTask: Task<Void, Never>?

    /// Start recording. Returns a stream of raw PCM buffers for speech recognition.
    @discardableResult
    func startRecording() -> AsyncStream<AVAudioPCMBuffer> {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("AudioRecorder: failed to configure session — \(error)")
            return AsyncStream { $0.finish() }
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let url = Self.newRecordingURL()

        // AAC file with PCM processing format matching the mic input
        let fileSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: inputFormat.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioFile = try AVAudioFile(
                forWriting: url,
                settings: fileSettings,
                commonFormat: inputFormat.commonFormat,
                interleaved: inputFormat.isInterleaved
            )
        } catch {
            print("AudioRecorder: failed to create audio file — \(error)")
            return AsyncStream { $0.finish() }
        }

        let (stream, continuation) = AsyncStream<AVAudioPCMBuffer>.makeStream()
        audioBufferContinuation = continuation

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self, !self.isPaused else { return }

            // Write to file
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                print("AudioRecorder: write error — \(error)")
            }

            // Forward for speech recognition
            self.audioBufferContinuation?.yield(buffer)

            // Compute level from raw samples
            let level = Self.computeLevel(from: buffer)
            Task { @MainActor [weak self] in
                guard let self else { return }
                let curved = cbrtf(level)
                if curved > self.currentLevel {
                    self.currentLevel = self.currentLevel * 0.3 + curved * 0.7
                } else {
                    self.currentLevel = self.currentLevel * 0.6 + curved * 0.4
                }
            }
        }

        do {
            try engine.start()
            audioEngine = engine
            recordedFileURL = url
            isRecording = true
            isPaused = false
        } catch {
            print("AudioRecorder: failed to start engine — \(error)")
            inputNode.removeTap(onBus: 0)
            continuation.finish()
            return AsyncStream { $0.finish() }
        }

        return stream
    }

    func pauseRecording() {
        isPaused = true
        currentLevel = 0
    }

    func resumeRecording() {
        isPaused = false
    }

    func stopRecording() -> URL? {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        audioBufferContinuation?.finish()
        audioBufferContinuation = nil

        let url = recordedFileURL
        isRecording = false
        isPaused = false
        currentLevel = 0
        return url
    }

    // MARK: - Playback

    func startPlayback() {
        guard let url = recordedFileURL else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.play()
            audioPlayer = player
            playbackDuration = player.duration
            isPlaying = true
            startPlaybackTimer()
        } catch {
            print("AudioRecorder: playback failed — \(error)")
        }
    }

    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
    }

    func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            if let player = audioPlayer, player.currentTime > 0, player.currentTime < player.duration {
                player.play()
                isPlaying = true
                startPlaybackTimer()
            } else {
                startPlayback()
            }
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playbackCurrentTime = 0
        stopPlaybackTimer()
    }

    func deleteRecording() {
        stopPlayback()
        if let url = recordedFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordedFileURL = nil
        playbackDuration = 0
        playbackCurrentTime = 0
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.playbackCurrentTime = 0
            self.stopPlaybackTimer()
        }
    }

    // MARK: - Playback Timer

    private func startPlaybackTimer() {
        stopPlaybackTimer()
        playbackTimerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { break }
                guard let self, let player = self.audioPlayer, player.isPlaying else { continue }
                self.playbackCurrentTime = player.currentTime
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimerTask?.cancel()
        playbackTimerTask = nil
    }

    // MARK: - Metering

    private static func computeLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let samples = channelData[0]
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var peak: Float = 0
        var sumSquares: Float = 0

        for i in 0..<count {
            let s = abs(samples[i])
            if s > peak { peak = s }
            sumSquares += s * s
        }

        let rms = sqrtf(sumSquares / Float(count))
        // Blend peak and RMS (70/30) — same ratio as previous dB-based approach
        return peak * 0.7 + rms * 0.3
    }

    // MARK: - File URL

    private static func newRecordingURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: "recordings")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = "dream_\(Date.now.timeIntervalSince1970).m4a"
        return dir.appending(path: name)
    }
}
