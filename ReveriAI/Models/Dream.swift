import Foundation
import SwiftData

@Model
final class Dream {
    var id: UUID
    var text: String
    var emotionRawValue: String?
    var createdAt: Date
    var audioFilePath: String?
    var isTranslated: Bool

    var emotion: DreamEmotion? {
        get {
            guard let raw = emotionRawValue else { return nil }
            return DreamEmotion(rawValue: raw)
        }
        set {
            emotionRawValue = newValue?.rawValue
        }
    }

    init(
        text: String,
        emotion: DreamEmotion? = nil,
        createdAt: Date = .now,
        audioFilePath: String? = nil,
        isTranslated: Bool = false
    ) {
        self.id = UUID()
        self.text = text
        self.emotionRawValue = emotion?.rawValue
        self.createdAt = createdAt
        self.audioFilePath = audioFilePath
        self.isTranslated = isTranslated
    }
}
