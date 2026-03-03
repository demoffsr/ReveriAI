import WatchConnectivity
import Observation

@Observable
final class WatchSessionManager: NSObject, WCSessionDelegate {
    var isReachable = false

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func transferAudioFile(url: URL, createdAt: Date, emotions: [String]) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.transferFile(
            url,
            metadata: [
                "createdAt": createdAt.timeIntervalSince1970,
                "emotions": emotions
            ]
        )
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error {
            print("Watch WCSession activation error: \(error)")
        }
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error {
            print("Watch file transfer failed: \(error)")
        }
    }
}
