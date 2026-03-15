import Testing
@testable import ReveriAI

@Suite("Caption Helpers")
@MainActor
struct CaptionHelpersTests {

    @Test("lowercaseFirst with Latin capital")
    func lowercaseFirstLatin() {
        let result = SpeechRecognitionService.lowercaseFirst("Hello")
        #expect(result == "hello")
    }

    @Test("lowercaseFirst with Cyrillic capital")
    func lowercaseFirstCyrillic() {
        let result = SpeechRecognitionService.lowercaseFirst("Привет")
        #expect(result == "привет")
    }

    @Test("endsWithSentencePunctuation returns true for period")
    func endsWithPeriod() {
        #expect(SpeechRecognitionService.endsWithSentencePunctuation("Done.") == true)
    }

    @Test("endsWithSentencePunctuation returns false for letter")
    func endsWithLetter() {
        #expect(SpeechRecognitionService.endsWithSentencePunctuation("Done") == false)
    }
}
