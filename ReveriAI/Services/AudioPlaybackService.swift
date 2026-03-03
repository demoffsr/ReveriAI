import AVFoundation
import SwiftUI

@Observable
final class AudioPlaybackService: NSObject, AVAudioPlayerDelegate {
    private(set) var currentURL: URL?
    private(set) var isPlaying = false
    private(set) var playbackProgress: CGFloat = 0
    private(set) var playbackCurrentTime: TimeInterval = 0
    private(set) var playbackDuration: TimeInterval = 0

    private var audioPlayer: AVAudioPlayer?
    private var timerTask: Task<Void, Never>?

    func play(url: URL) {
        // If same URL is paused, just resume
        if let player = audioPlayer, currentURL == url {
            resume(player: player)
            return
        }

        // Stop any current playback
        stopInternal()

        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.m4a.rawValue)
            player.delegate = self
            player.prepareToPlay()
            audioPlayer = player
            currentURL = url
            playbackDuration = player.duration
            player.play()
            isPlaying = true
            startTimer()
        } catch {
            #if DEBUG
            print("AudioPlaybackService: playback init failed — \(error)")
            #endif
        }
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    func toggle(url: URL) {
        if currentURL == url && isPlaying {
            pause()
        } else {
            play(url: url)
        }
    }

    func stop() {
        stopInternal()
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopTimer()
            self.isPlaying = false
            self.playbackProgress = 0
            self.playbackCurrentTime = 0
            self.currentURL = nil
            self.audioPlayer = nil
        }
    }

    // MARK: - Private

    private func resume(player: AVAudioPlayer) {
        player.play()
        isPlaying = true
        startTimer()
    }

    private func stopInternal() {
        audioPlayer?.stop()
        stopTimer()
        audioPlayer = nil
        isPlaying = false
        playbackProgress = 0
        playbackCurrentTime = 0
        playbackDuration = 0
        currentURL = nil
    }

    private func startTimer() {
        stopTimer()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, let self else { break }
                guard let player = self.audioPlayer, player.isPlaying else { continue }
                self.playbackCurrentTime = player.currentTime
                self.playbackDuration = player.duration
                self.playbackProgress = player.duration > 0 ? CGFloat(player.currentTime / player.duration) : 0
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var audioPlayback: AudioPlaybackService = AudioPlaybackService()
}
