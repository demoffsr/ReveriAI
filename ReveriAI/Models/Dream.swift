import Foundation
import SwiftData

@Model
final class Dream {
    var id: UUID
    var title: String = ""
    var text: String
    // Legacy — keep for backwards compatibility
    var emotionRawValue: String?
    var emotionValues: [String] = []
    var createdAt: Date
    var audioFilePath: String?
    var imageURL: String?
    var isTranslated: Bool

    var emotions: [DreamEmotion] {
        get { emotionValues.compactMap { DreamEmotion(rawValue: $0) } }
        set { emotionValues = newValue.map(\.rawValue) }
    }

    var emotion: DreamEmotion? {
        get {
            emotions.first ?? DreamEmotion(rawValue: emotionRawValue ?? "")
        }
        set {
            emotionRawValue = newValue?.rawValue
        }
    }

    init(
        text: String,
        title: String = "",
        emotions: [DreamEmotion] = [],
        createdAt: Date = .now,
        audioFilePath: String? = nil,
        imageURL: String? = nil,
        isTranslated: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.text = text
        self.emotionValues = emotions.map(\.rawValue)
        self.emotionRawValue = emotions.first?.rawValue
        self.createdAt = createdAt
        self.audioFilePath = audioFilePath
        self.imageURL = imageURL
        self.isTranslated = isTranslated
    }
}
