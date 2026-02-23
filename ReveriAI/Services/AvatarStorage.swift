import SwiftUI

@Observable
@MainActor
final class AvatarStorage {
    var avatarImage: UIImage?

    private static let fileName = "user_avatar.jpg"

    init() {
        // Don't load in init — call loadFromDisk() when ready
    }

    func loadFromDisk() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let image = UIImage(data: data) else { return }
        avatarImage = image
    }

    func save(uiImage: UIImage) {
        avatarImage = uiImage
        guard let data = uiImage.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    func delete() {
        avatarImage = nil
        try? FileManager.default.removeItem(at: Self.fileURL)
    }

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
}
