import SwiftUI

@Observable
@MainActor
final class HeaderBackgroundStorage {
    var backgroundImage: UIImage?
    var selectedPreset: WallpaperPreset?

    private static let fileName = "header_background.jpg"
    private static let presetKey = "headerWallpaperPreset"

    init() {
        // Don't load in init — call loadFromDisk() when ready
    }

    func loadFromDisk() {
        // Load preset from UserDefaults
        if let raw = UserDefaults.standard.string(forKey: Self.presetKey),
           let preset = WallpaperPreset(rawValue: raw) {
            selectedPreset = preset
        }

        // Load custom photo
        guard let data = try? Data(contentsOf: Self.fileURL),
              let image = UIImage(data: data) else { return }
        backgroundImage = image
    }

    func save(uiImage: UIImage) {
        backgroundImage = uiImage
        selectedPreset = nil
        UserDefaults.standard.removeObject(forKey: Self.presetKey)
        guard let data = uiImage.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: Self.fileURL, options: [.atomic, .completeFileProtection])
    }

    func selectPreset(_ preset: WallpaperPreset) {
        selectedPreset = preset
        backgroundImage = nil
        UserDefaults.standard.set(preset.rawValue, forKey: Self.presetKey)
        try? FileManager.default.removeItem(at: Self.fileURL)
    }

    func delete() {
        backgroundImage = nil
        selectedPreset = nil
        UserDefaults.standard.removeObject(forKey: Self.presetKey)
        try? FileManager.default.removeItem(at: Self.fileURL)
    }

    var hasCustomSelection: Bool {
        backgroundImage != nil || selectedPreset != nil
    }

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
}
