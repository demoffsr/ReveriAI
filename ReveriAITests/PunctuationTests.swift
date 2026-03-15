import Testing
@testable import ReveriAI

@Suite("Speech Punctuation")
@MainActor
struct PunctuationTests {

    @Test("Russian question word adds ?")
    func russianQuestionWord() {
        let result = SpeechRecognitionService.punctuateSegment("почему я летал")
        #expect(result == "почему я летал?")
    }

    @Test("Fillers before question word still adds ?")
    func fillersBeforeQuestion() {
        let result = SpeechRecognitionService.punctuateSegment("ну а где мой кот")
        #expect(result == "ну а где мой кот?")
    }

    @Test("Particle ли makes question")
    func particleLi() {
        let result = SpeechRecognitionService.punctuateSegment("правда ли это")
        #expect(result == "правда ли это?")
    }

    @Test("неужели makes question")
    func neuzheli() {
        let result = SpeechRecognitionService.punctuateSegment("неужели это правда")
        #expect(result == "неужели это правда?")
    }

    @Test("Plain statement gets period")
    func plainStatement() {
        let result = SpeechRecognitionService.punctuateSegment("я шёл по улице")
        #expect(result == "я шёл по улице.")
    }

    @Test("Already punctuated text unchanged")
    func alreadyPunctuated() {
        let result = SpeechRecognitionService.punctuateSegment("Hello world.")
        #expect(result == "Hello world.")
    }

    @Test("Ellipsis preserved")
    func ellipsisPreserved() {
        let result = SpeechRecognitionService.punctuateSegment("I was falling...")
        #expect(result == "I was falling...")
    }

    @Test("Short text under 2 chars unchanged")
    func shortTextPassthrough() {
        let result = SpeechRecognitionService.punctuateSegment("я")
        #expect(result == "я")
    }
}
