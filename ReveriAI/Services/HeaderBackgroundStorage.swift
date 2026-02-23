import SwiftUI

@Observable
@MainActor
final class HeaderBackgroundStorage {
    var backgroundImage: UIImage?

    private static let fileName = "header_background.jpg"

    init() {
        loadFromDisk()
    }

    func save(uiImage: UIImage) {
        backgroundImage = uiImage
        guard let data = uiImage.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    func delete() {
        backgroundImage = nil
        try? FileManager.default.removeItem(at: Self.fileURL)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let image = UIImage(data: data) else { return }
        backgroundImage = image
    }

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
}
