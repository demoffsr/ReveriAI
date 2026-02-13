import Foundation

enum SpeechLocale: String, CaseIterable, Identifiable {
    case russian = "ru-RU"
    case english = "en-US"
    case german = "de-DE"
    case french = "fr-FR"
    case spanish = "es-ES"
    case italian = "it-IT"
    case portuguese = "pt-BR"
    case japanese = "ja-JP"
    case korean = "ko-KR"
    case chinese = "zh-CN"
    case arabic = "ar-SA"
    case turkish = "tr-TR"
    case hindi = "hi-IN"

    var id: String { rawValue }

    var identifier: String { rawValue }

    var shortCode: String {
        String(rawValue.prefix(2)).uppercased()
    }

    var displayName: String {
        let locale = Locale(identifier: rawValue)
        return locale.localizedString(forIdentifier: rawValue) ?? rawValue
    }

    static var defaultLocale: SpeechLocale {
        let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        return allCases.first { $0.rawValue.hasPrefix(deviceLanguage) } ?? .english
    }
}
