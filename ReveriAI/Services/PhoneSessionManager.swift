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
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: file.fileURL, to: destURL)
        } catch {
            print("Failed to save Watch audio: \(error)")
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

    private func processTransfer(_ transfer: PendingAudioTransfer, container: ModelContainer) {
        Task { @MainActor in
            let context = container.mainContext
            let dream = Dream(text: "", createdAt: transfer.createdAt)
            dream.emotionValues = transfer.emotions
            dream.audioFilePath = "recordings/\(transfer.fileName)"
            context.insert(dream)
            try? context.save()
        }
    }
}
