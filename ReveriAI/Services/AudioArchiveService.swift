import Foundation

enum AudioArchiveService {
    private static let recordingsDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
    }()

    private static let archiveDirectory: URL = {
        let dir = recordingsDirectory.appendingPathComponent("archive")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Moves an audio file from `recordings/` to `recordings/archive/` with a timestamp suffix.
    /// Returns the archive filename on success, nil on failure.
    @discardableResult
    static func archiveAudio(filename: String) -> String? {
        let source = recordingsDirectory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: source.path) else { return nil }

        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        let timestamp = Int(Date.now.timeIntervalSince1970)
        let archiveName = "\(name)_archived_\(timestamp).\(ext)"
        let destination = archiveDirectory.appendingPathComponent(archiveName)

        do {
            try FileManager.default.moveItem(at: source, to: destination)
            return archiveName
        } catch {
            return nil
        }
    }
}
