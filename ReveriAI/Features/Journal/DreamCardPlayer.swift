import Accelerate
import AVFoundation
import SwiftUI

struct DreamCardPlayer: View {
    let audioURL: URL
    var style: Style = .compact

    enum Style {
        case compact   // DreamCard in journal list
        case detail    // DreamDetailView
    }

    @Environment(\.theme) private var theme
    @State private var player: CardAudioPlayer?
    @State private var bars: [CGFloat] = []
    @State private var isPlaying = false
    @State private var playbackProgress: CGFloat = 0

    private var buttonSize: CGFloat { style == .detail ? 44 : 32 }
    private var iconSize: CGFloat { style == .detail ? 16 : 12 }
    private var waveformHeight: CGFloat { style == .detail ? 48 : 32 }
    private var spacing: CGFloat { style == .detail ? 14 : 9 }

    var body: some View {
        HStack(spacing: spacing) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(theme.accent)
                    .clipShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())

            CardWaveformView(
                bars: bars,
                playbackProgress: playbackProgress,
                frameHeight: waveformHeight
            )
        }
        .task {
            let analyzed = await AudioAnalysisCache.shared.bars(for: audioURL)
            bars = analyzed.isEmpty ? AudioFileAnalyzer.placeholderBars() : analyzed
        }
        .onDisappear {
            player?.stop()
            player = nil
        }
    }

    private func togglePlayback() {
        HapticService.impact(.light)
        if player == nil {
            let p = CardAudioPlayer(url: audioURL) { time, duration in
                playbackProgress = duration > 0 ? CGFloat(time / duration) : 0
            } onFinish: {
                isPlaying = false
                playbackProgress = 0
            }
            player = p
        }

        guard let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
}

// MARK: - CardAudioPlayer

/// Self-contained AVAudioPlayer wrapper for DreamCard playback.
private final class CardAudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    private var timerTask: Task<Void, Never>?
    private let onProgress: (TimeInterval, TimeInterval) -> Void
    private let onFinish: () -> Void

    init(url: URL, onProgress: @escaping (TimeInterval, TimeInterval) -> Void, onFinish: @escaping () -> Void) {
        self.onProgress = onProgress
        self.onFinish = onFinish
        super.init()

        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.m4a.rawValue)
            player.delegate = self
            player.prepareToPlay()
            self.audioPlayer = player
        } catch {
            print("DreamCardPlayer: playback init failed — \(error)")
        }
    }

    func play() {
        audioPlayer?.play()
        startTimer()
    }

    func pause() {
        audioPlayer?.pause()
        stopTimer()
    }

    func stop() {
        audioPlayer?.stop()
        stopTimer()
        audioPlayer = nil
    }

    private func startTimer() {
        stopTimer()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, let self else { break }
                guard let player = self.audioPlayer, player.isPlaying else { continue }
                self.onProgress(player.currentTime, player.duration)
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.stopTimer()
            self?.onFinish()
        }
    }
}

// MARK: - AudioAnalysisCache

@MainActor
final class AudioAnalysisCache {
    static let shared = AudioAnalysisCache()
    private var cache: [String: [CGFloat]] = [:]
    private var inFlight: [String: Task<[CGFloat], Never>] = [:]

    func bars(for url: URL) async -> [CGFloat] {
        let key = url.path
        if let cached = cache[key] { return cached }
        if let existing = inFlight[key] { return await existing.value }
        let task = Task { await AudioFileAnalyzer.analyzeBars(url: url) }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        if !result.isEmpty { cache[key] = result }
        return result
    }
}

// MARK: - AudioFileAnalyzer

enum AudioFileAnalyzer {
    /// Generate placeholder bars when audio file can't be analyzed
    static func placeholderBars(count: Int = 75) -> [CGFloat] {
        (0..<count).map { _ in CGFloat.random(in: 2...24) }
    }

    static func analyzeBars(url: URL) async -> [CGFloat] {
        await Task.detached(priority: .utility) {
            computeBars(url: url)
        }.value
    }

    private nonisolated static func computeBars(url: URL) -> [CGFloat] {
        let targetBarCount = 75
        let minHeight: CGFloat = 2
        let maxHeight: CGFloat = 24

        guard let audioFile = try? AVAudioFile(forReading: url) else { return [] }

        let format = audioFile.processingFormat
        let totalFrames = AVAudioFrameCount(audioFile.length)
        guard totalFrames > 0 else { return [] }

        let framesPerBar = max(1, totalFrames / AVAudioFrameCount(targetBarCount))
        let actualBarCount = Int(totalFrames / framesPerBar)
        guard actualBarCount > 0 else { return [] }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else { return [] }
        do {
            try audioFile.read(into: buffer)
        } catch {
            print("AudioFileAnalyzer: read error — \(error)")
            return []
        }

        guard let channelData = buffer.floatChannelData else { return [] }
        let samples = channelData[0]

        var rmsValues: [Float] = []
        rmsValues.reserveCapacity(actualBarCount)

        for i in 0..<actualBarCount {
            let start = Int(UInt64(i) * UInt64(framesPerBar))
            let count = min(Int(framesPerBar), Int(totalFrames) - start)
            guard count > 0 else { continue }

            var rms: Float = 0
            vDSP_rmsqv(samples.advanced(by: start), 1, &rms, vDSP_Length(count))
            rmsValues.append(rms)
        }

        guard let maxRMS = rmsValues.max(), maxRMS > 0 else {
            return Array(repeating: minHeight, count: actualBarCount)
        }

        return rmsValues.map { rms in
            let normalized = min(1, rms / maxRMS)
            let curved = CGFloat(cbrtf(normalized))
            return minHeight + curved * (maxHeight - minHeight)
        }
    }
}
