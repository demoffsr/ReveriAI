import Foundation
import SwiftData

@Model
final class Dream {
    #Index<Dream>([\.createdAt])

    /// Set by AuthService at app launch. Auto-tags new records with owner.
    nonisolated(unsafe) static var defaultUserId: String?

    var id: UUID
    var userId: String?
    var title: String = ""
    var text: String
    // Legacy — keep for backwards compatibility
    var emotionRawValue: String?
    var emotionValues: [String] = []
    var createdAt: Date
    var audioFilePath: String?
    var imageURL: String?
    var imagePath: String?
    var interpretation: String?
    var whisperTranscript: String?
    var originalTranscript: String?
    var isTranslated: Bool
    var audioDuration: TimeInterval?
    var isArchived: Bool = false
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

    var isTranscribingAudio: Bool {
        audioFilePath != nil && whisperTranscript == nil
    }

    var hasTranscriptToggle: Bool {
        whisperTranscript != nil && originalTranscript != nil
    }

    /// Resets all AI-generated content so it can be regenerated after editing.
    func resetAIContent() {
        title = ""
        interpretation = nil
        imageURL = nil
        imagePath = nil
    }

    init(
        text: String,
        title: String = "",
        emotions: [DreamEmotion] = [],
        createdAt: Date = .now,
        audioFilePath: String? = nil,
        imageURL: String? = nil,
        imagePath: String? = nil,
        isTranslated: Bool = false,
        whisperTranscript: String? = nil,
        originalTranscript: String? = nil,
        audioDuration: TimeInterval? = nil
    ) {
        self.id = UUID()
        self.userId = Self.defaultUserId
        self.title = title
        self.text = text
        self.emotionValues = emotions.map(\.rawValue)
        self.emotionRawValue = emotions.first?.rawValue
        self.createdAt = createdAt
        self.audioFilePath = audioFilePath
        self.imageURL = imageURL
        self.imagePath = imagePath
        self.isTranslated = isTranslated
        self.whisperTranscript = whisperTranscript
        self.originalTranscript = originalTranscript
        self.audioDuration = audioDuration
    }
}
