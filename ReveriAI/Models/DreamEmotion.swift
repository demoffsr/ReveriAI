import SwiftUI

enum DreamEmotion: String, Codable, CaseIterable, Identifiable {
    case joyful
    case inLove
    case calm
    case confused
    case anxious
    case scared
    case angry

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .joyful: "Joyful"
        case .inLove: "In Love"
        case .calm: "Calm"
        case .confused: "Confused"
        case .anxious: "Anxious"
        case .scared: "Scared"
        case .angry: "Angry"
        }
    }

    var emoji: String {
        switch self {
        case .joyful: "😊"
        case .inLove: "😍"
        case .calm: "😌"
        case .confused: "😕"
        case .anxious: "😰"
        case .scared: "😱"
        case .angry: "😡"
        }
    }

    var iconName: String {
        switch self {
        case .joyful: "EmotionJoyful"
        case .inLove: "EmotionInLove"
        case .calm: "EmotionCalm"
        case .confused: "EmotionConfused"
        case .anxious: "EmotionAnxious"
        case .scared: "EmotionScared"
        case .angry: "EmotionAngry"
        }
    }

    var journalIcon: String {
        switch self {
        case .joyful: "JournalIconJoyful"
        case .inLove: "JournalIconInLove"
        case .calm: "JournalIconCalm"
        case .confused: "JournalIconConfused"
        case .anxious: "JournalIconAnxious"
        case .scared: "JournalIconScared"
        case .angry: "JournalIconAngry"
        }
    }

    var color: Color {
        switch self {
        case .joyful: Color(hex: "4CAF50")
        case .inLove: Color(hex: "E91E63")
        case .calm: Color(hex: "FFC107")
        case .confused: Color(hex: "9C27B0")
        case .anxious: Color(hex: "2196F3")
        case .scared: Color(hex: "FF9800")
        case .angry: Color(hex: "F44336")
        }
    }
}
