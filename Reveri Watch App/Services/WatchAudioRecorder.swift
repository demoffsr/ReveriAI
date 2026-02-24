import AVFoundation
import Observation

@Observable
final class WatchAudioRecorder {
    var isRecording = false
    var currentLevel: Float = 0  // 0...1 for waveform
    var duration: TimeInterval = 0
    var audioFilePath: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let fileName = "dream_\(Int(Date().timeIntervalSince1970)).m4a"
        let url = Self.recordingsDirectory.appendingPathComponent(fileName)

        try FileManager.default.createDirectory(
            at: Self.recordingsDirectory,
            withIntermediateDirectories: true
        )

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()

        audioFilePath = fileName
        isRecording = true
        duration = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            let linear = max(0, min(1, (power + 60) / 60))
            self.currentLevel = linear
            self.duration = recorder.currentTime
        }
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func deleteRecording() {
        guard let path = audioFilePath else { return }
        let url = Self.recordingsDirectory.appendingPathComponent(path)
        try? FileManager.default.removeItem(at: url)
        audioFilePath = nil
    }

    var audioFileURL: URL? {
        guard let path = audioFilePath else { return nil }
        return Self.recordingsDirectory.appendingPathComponent(path)
    }

    static var recordingsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
    }
}
