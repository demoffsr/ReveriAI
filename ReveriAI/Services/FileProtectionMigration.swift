import Foundation

enum FileProtectionMigration {
    static func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "fileProtectionMigrated") else { return }

        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // Audio recordings → .completeUnlessOpen (background recording needs open handle)
        let recordings = docs.appendingPathComponent("recordings")
        setProtection(.completeUnlessOpen, directory: recordings)

        // Dream images → .complete
        let images = docs.appendingPathComponent("dream-images")
        setProtection(.complete, directory: images)

        // Individual files → .complete
        for name in ["user_avatar.jpg", "header_background.jpg"] {
            let path = docs.appendingPathComponent(name).path
            if fm.fileExists(atPath: path) {
                try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: path)
            }
        }

        UserDefaults.standard.set(true, forKey: "fileProtectionMigrated")
    }

    private static func setProtection(_ type: FileProtectionType, directory: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return }
        try? fm.setAttributes([.protectionKey: type], ofItemAtPath: directory.path)
        if let files = try? fm.contentsOfDirectory(atPath: directory.path) {
            for file in files {
                let path = directory.appendingPathComponent(file).path
                try? fm.setAttributes([.protectionKey: type], ofItemAtPath: path)
            }
        }
    }
}
