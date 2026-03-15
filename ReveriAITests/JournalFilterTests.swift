import Testing
import SwiftData
@testable import ReveriAI

@Suite("Journal Filters")
@MainActor
struct JournalFilterTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            "ReveriAITests",
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: Dream.self, DreamFolder.self,
            configurations: config
        )
    }

    @Test("Emotion filter returns only matching dreams")
    func emotionFilter() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let joyful = Dream(text: "happy dream", emotions: [.joyful])
        let scared = Dream(text: "scary dream", emotions: [.scared])
        let calm = Dream(text: "calm dream", emotions: [.calm])
        context.insert(joyful)
        context.insert(scared)
        context.insert(calm)
        try context.save()

        let vm = JournalViewModel()
        vm.selectedEmotion = .joyful
        vm.updateFilters(allDreams: [joyful, scared, calm])

        #expect(vm.filteredDreams.count == 1)
        #expect(vm.filteredDreams.first?.text == "happy dream")
    }

    @Test("Search filter matches text and title")
    func searchFilter() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let dream1 = Dream(text: "flying over mountains", title: "Mountain Flight")
        let dream2 = Dream(text: "swimming in ocean")
        let dream3 = Dream(text: "walking in forest", title: "Forest Walk")
        context.insert(dream1)
        context.insert(dream2)
        context.insert(dream3)
        try context.save()

        let vm = JournalViewModel()
        vm.searchText = "mountain"
        vm.updateFilters(allDreams: [dream1, dream2, dream3])

        #expect(vm.filteredDreams.count == 1)
        #expect(vm.filteredDreams.first?.text == "flying over mountains")
    }

    @Test("Archived dreams are excluded")
    func archivedExcluded() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let active = Dream(text: "active dream")
        let archived = Dream(text: "archived dream")
        archived.isArchived = true
        context.insert(active)
        context.insert(archived)
        try context.save()

        let vm = JournalViewModel()
        vm.updateFilters(allDreams: [active, archived])

        #expect(vm.filteredDreams.count == 1)
        #expect(vm.filteredDreams.first?.text == "active dream")
    }
}
