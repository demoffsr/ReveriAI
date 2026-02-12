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

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var meteringTask: Task<Void, Never>?
    private var playbackTimerTask: Task<Void, Never>?

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("AudioRecorder: failed to configure session — \(error)")
            return
        }

        let url = Self.newRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record()
            audioRecorder = recorder
            recordedFileURL = url
            isRecording = true
            isPaused = false
            startMetering()
        } catch {
            print("AudioRecorder: failed to start — \(error)")
        }
    }

    func pauseRecording() {
        audioRecorder?.pause()
        isPaused = true
        stopMetering()
        currentLevel = 0
    }

    func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
        startMetering()
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        stopMetering()
        let url = recordedFileURL
        audioRecorder = nil
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

    private func startMetering() {
        meteringTask?.cancel()
        meteringTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { break }
                guard let self, let recorder = self.audioRecorder, recorder.isRecording else { continue }
                recorder.updateMeters()
                // Peak power is more responsive than average for visual feedback
                let peak = recorder.peakPower(forChannel: 0)
                let avg = recorder.averagePower(forChannel: 0)
                // Blend: mostly peak for responsiveness, touch of average for body
                let db = peak * 0.7 + avg * 0.3
                // Proper amplitude conversion: dB → linear (0...1)
                // -160 dB = silence, 0 dB = max. Clamp floor at -50 dB.
                let amplitude = db > -50 ? powf(10, db / 20) : 0
                // Power curve to spread the speech range (~0.01–0.5 amplitude)
                // across visible heights. Cube root expands low-mid range nicely.
                let curved = cbrtf(amplitude)
                // Responsive smoothing: fast attack, slower decay
                let target = curved
                if target > self.currentLevel {
                    self.currentLevel = self.currentLevel * 0.3 + target * 0.7
                } else {
                    self.currentLevel = self.currentLevel * 0.6 + target * 0.4
                }
            }
        }
    }

    private func stopMetering() {
        meteringTask?.cancel()
        meteringTask = nil
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
