import WatchConnectivity
import SwiftData
import Observation

@Observable
final class PhoneSessionManager: NSObject, WCSessionDelegate {
    private var modelContainer: ModelContainer?
    private let pendingTransfersKey = "pendingAudioTransfers"

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func configure(with container: ModelContainer) {
        self.modelContainer = container
        Self.fixWatchAudioPaths(container: container)
        processPendingTransfers()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let metadata = file.metadata ?? [:]
        let createdAt: Date
        if let timestamp = metadata["createdAt"] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: timestamp)
        } else {
            createdAt = Date()
        }
        let emotions = metadata["emotions"] as? [String] ?? []

        let fileName = "watch_\(Int(Date().timeIntervalSince1970)).m4a"
        let destDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
        let destURL = destDir.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(
                at: destDir,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
            )
            try FileManager.default.copyItem(at: file.fileURL, to: destURL)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUnlessOpen],
                ofItemAtPath: destURL.path
            )
            try FileManager.default.removeItem(at: file.fileURL)
        } catch {
            #if DEBUG
            print("Failed to save Watch audio: \(error)")
            #endif
            return
        }

        let transfer = PendingAudioTransfer(fileName: fileName, createdAt: createdAt, emotions: emotions)

        if let container = modelContainer {
            processTransfer(transfer, container: container)
        } else {
            savePendingTransfer(transfer)
        }
    }

    // MARK: - Pending Queue

    private struct PendingAudioTransfer: Codable {
        let fileName: String
        let createdAt: Date
        let emotions: [String]
    }

    private func savePendingTransfer(_ transfer: PendingAudioTransfer) {
        var pending = loadPendingTransfers()
        pending.append(transfer)
        if let data = try? JSONEncoder().encode(pending) {
            UserDefaults.standard.set(data, forKey: pendingTransfersKey)
        }
    }

    private func loadPendingTransfers() -> [PendingAudioTransfer] {
        guard let data = UserDefaults.standard.data(forKey: pendingTransfersKey),
              let transfers = try? JSONDecoder().decode([PendingAudioTransfer].self, from: data) else {
            return []
        }
        return transfers
    }

    private func clearPendingTransfers() {
        UserDefaults.standard.removeObject(forKey: pendingTransfersKey)
    }

    private func processPendingTransfers() {
        guard let container = modelContainer else { return }
        let pending = loadPendingTransfers()
        guard !pending.isEmpty else { return }
        clearPendingTransfers()
        for transfer in pending {
            processTransfer(transfer, container: container)
        }
    }

    /// One-time fix: strip "recordings/" prefix from Watch dream audioFilePaths
    private static func fixWatchAudioPaths(container: ModelContainer) {
        Task { @MainActor in
            let context = container.mainContext
            let descriptor = FetchDescriptor<Dream>()
            guard let dreams = try? context.fetch(descriptor) else { return }
            var fixed = 0
            for dream in dreams {
                guard let path = dream.audioFilePath,
                      path.hasPrefix("recordings/") else { continue }
                dream.audioFilePath = String(path.dropFirst("recordings/".count))
                fixed += 1
                // Re-trigger transcription if needed
                if dream.whisperTranscript == nil {
                    let locale = SpeechLocale(
                        rawValue: UserDefaults.standard.string(forKey: "speechRecognitionLocale") ?? ""
                    ) ?? .russian
                    DreamAIService.transcribeAudioInBackground(
                        dreamID: dream.persistentModelID,
                        audioFileName: dream.audioFilePath!,
                        locale: locale,
                        modelContainer: container
                    )
                }
            }
            if fixed > 0 {
                try? context.save()
                #if DEBUG
                print("Fixed \(fixed) Watch dream audio path(s)")
                #endif
            }
        }
    }

    private func processTransfer(_ transfer: PendingAudioTransfer, container: ModelContainer) {
        Task { @MainActor in
            let context = container.mainContext
            let dream = Dream(text: "", createdAt: transfer.createdAt)
            dream.emotionValues = transfer.emotions
            dream.audioFilePath = transfer.fileName
            context.insert(dream)
            try? context.save()

            // Trigger Whisper transcription
            let locale = SpeechLocale(
                rawValue: UserDefaults.standard.string(forKey: "speechRecognitionLocale") ?? ""
            ) ?? .russian
            DreamAIService.transcribeAudioInBackground(
                dreamID: dream.persistentModelID,
                audioFileName: transfer.fileName,
                locale: locale,
                modelContainer: container
            )
        }
    }
}
