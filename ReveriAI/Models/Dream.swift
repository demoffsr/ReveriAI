import Foundation
import SwiftData

@Model
final class Dream {
    #Index<Dream>([\.createdAt])

    var id: UUID
    var title: String = ""
    var text: String
    // Legacy — keep for backwards compatibility
    var emotionRawValue: String?
    var emotionValues: [String] = []
    var createdAt: Date
    var audioFilePath: String?
    var imageURL: String?
    var interpretation: String?
    var isTranslated: Bool
    var folder: DreamFolder?

    @Transient private var _cachedEmotions: [DreamEmotion]?
    @Transient private var _cachedEmotionValues: [String]?

    var emotions: [DreamEmotion] {
        get {
            if let cached = _cachedEmotions, _cachedEmotionValues == emotionValues {
                return cached
            }
            let result = emotionValues.compactMap { DreamEmotion(rawValue: $0) }
            _cachedEmotions = result
            _cachedEmotionValues = emotionValues
            return result
        }
        set {
            emotionValues = newValue.map(\.rawValue)
            _cachedEmotions = newValue
            _cachedEmotionValues = emotionValues
        }
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
