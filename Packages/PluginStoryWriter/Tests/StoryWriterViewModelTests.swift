import Foundation
import Testing

@testable import StoryWriterPlugin

@MainActor
struct StoryWriterViewModelTests {
    @Test func selectionCrudAndMarkdownFlowsStayInSyncWithStore() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let viewModel = StoryWriterViewModel(store: StoryStore(pluginDirectory: directory))

        await viewModel.loadStories()
        #expect(viewModel.stories.isEmpty)
        #expect(viewModel.currentStoryID == nil)
        #expect(await viewModel.createChapter(title: "No story") == nil)
        #expect(await viewModel.createCharacter(name: "No story") == nil)
        #expect(await viewModel.importMarkdownAsChapter(title: "No story", content: "") == nil)
        #expect(await viewModel.exportStoryAsMarkdown() == nil)

        let firstStory = await viewModel.createStory(title: "First")
        #expect(viewModel.currentStoryID == firstStory.id)
        #expect(viewModel.currentStory == firstStory)
        #expect(viewModel.selectedNodeID == firstStory.id)
        #expect(viewModel.selectedNodeKind == .story)

        guard let chapter = await viewModel.createChapter(title: "Opening"),
              let character = await viewModel.createCharacter(name: "Rin"),
              let imported = await viewModel.importMarkdownAsChapter(title: "Imported", content: "A new beginning.") else {
            Issue.record("Could not create story content")
            return
        }
        #expect(viewModel.chapters.map(\.id) == [chapter.id, imported.id])
        #expect(viewModel.characters.map(\.id) == [character.id])
        #expect(viewModel.selectedNodeID == character.id)
        #expect(viewModel.selectedNodeKind == .character)

        var changedStory = firstStory
        changedStory.synopsis = "Updated synopsis"
        await viewModel.updateStory(changedStory)
        #expect(viewModel.currentStory?.synopsis == "Updated synopsis")

        var changedChapter = chapter
        changedChapter.title = "Revised opening"
        await viewModel.updateChapter(changedChapter)
        #expect(viewModel.chapters.first(where: { $0.id == chapter.id })?.title == "Revised opening")

        var changedCharacter = character
        changedCharacter.notes = "Finds the hidden door."
        await viewModel.updateCharacter(changedCharacter)
        #expect(viewModel.characters.first?.notes == "Finds the hidden door.")
        #expect(viewModel.selectedCharacter()?.id == character.id)
        #expect(viewModel.selectedChapter() == nil)

        let markdown = await viewModel.exportStoryAsMarkdown()
        #expect(markdown?.contains("# First") == true)
        #expect(markdown?.contains("## Imported\n\nA new beginning.") == true)

        await viewModel.deleteCharacter(id: character.id)
        #expect(viewModel.characters.isEmpty)
        #expect(viewModel.selectedNodeID == firstStory.id)
        #expect(viewModel.selectedNodeKind == .story)

        await viewModel.deleteChapter(id: imported.id)
        #expect(viewModel.chapters.map(\.id) == [chapter.id])
        await viewModel.selectStory(id: nil)
        #expect(viewModel.currentStoryID == nil)
        #expect(viewModel.chapters.isEmpty)
        #expect(viewModel.characters.isEmpty)
        #expect(viewModel.selectedNodeID == nil)
        #expect(viewModel.selectedNodeKind == .story)
    }

    @Test func reloadPreservesExistingSelectionAndFallsBackAfterDeletion() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let viewModel = StoryWriterViewModel(store: StoryStore(pluginDirectory: directory))
        let firstStory = await viewModel.createStory(title: "First")
        let secondStory = await viewModel.createStory(title: "Second")

        await viewModel.reloadFromDisk()
        #expect(viewModel.currentStoryID == secondStory.id)
        #expect(viewModel.stories.map(\.id).contains(firstStory.id))

        await viewModel.deleteStory(id: secondStory.id)
        #expect(viewModel.currentStoryID == firstStory.id)
        #expect(viewModel.currentStory?.title == "First")

        await viewModel.deleteStory(id: firstStory.id)
        #expect(viewModel.currentStoryID == nil)
        #expect(viewModel.stories.isEmpty)
        #expect(viewModel.selectedNodeID == nil)

        await viewModel.reloadFromDisk()
        #expect(viewModel.currentStoryID == nil)
        #expect(viewModel.chapters.isEmpty)
        #expect(viewModel.characters.isEmpty)
    }
}

@MainActor
@Test func changeObserverBroadcastsAndCancellationIsIdempotent() {
    var firstCount = 0
    var secondCount = 0
    let first = StoryWriterChangeObserver { firstCount += 1 }
    let second = StoryWriterChangeObserver { secondCount += 1 }

    StoryWriterChangeCenter.shared.notify()
    first.cancel()
    first.cancel()
    StoryWriterChangeCenter.shared.notify()
    second.cancel()
    StoryWriterChangeCenter.shared.notify()

    #expect(firstCount == 1)
    #expect(secondCount == 2)
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("StoryWriterViewModelTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
