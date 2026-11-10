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

    @Test func reloadKeepsSelectedChapterAndRefreshesItsContent() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StoryStore(pluginDirectory: directory)
        let viewModel = StoryWriterViewModel(store: store)
        let story = await viewModel.createStory(title: "First")
        guard let chapter = await viewModel.createChapter(title: "Opening") else {
            Issue.record("Could not create chapter")
            return
        }
        await viewModel.selectStory(id: story.id)
        viewModel.selectedNodeID = chapter.id
        viewModel.selectedNodeKind = .chapter

        var updated = chapter
        updated.title = "Revised by agent"
        updated.content = "New body"
        await store.updateChapter(updated)

        await viewModel.reloadFromDisk()

        #expect(viewModel.currentStoryID == story.id)
        #expect(viewModel.selectedNodeID == chapter.id, "重载不得把章节选择改回故事概览")
        #expect(viewModel.selectedNodeKind == .chapter)
        #expect(viewModel.chapters.first?.title == "Revised by agent")
        #expect(viewModel.chapters.first?.content == "New body")

        // 只有原选中节点确实不存在时才回退到故事概览。
        await store.deleteChapter(id: chapter.id, storyID: story.id)
        await viewModel.reloadFromDisk()

        #expect(viewModel.selectedNodeID == story.id)
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

@MainActor
struct StoryEditorDraftTests {
    @Test func cleanDraftAdoptsExternalSynopsisAndTitle() {
        let story = Story(title: "Old", synopsis: "Old synopsis")
        var draft = StoryEditorDraft(story: story)
        var incoming = story
        incoming.title = "Agent title"
        incoming.synopsis = "Agent synopsis"

        draft.applyExternalUpdate(incoming)

        #expect(draft.synopsis == "Agent synopsis")
        #expect(draft.storyToSave().title == "Agent title")
        #expect(!draft.hasUnsavedSynopsis)
    }

    @Test func dirtySynopsisKeepsLocalTextButSavesAgainstLatestExternalVersion() {
        let story = Story(title: "Old", synopsis: "Old synopsis")
        var draft = StoryEditorDraft(story: story)
        draft.updateSynopsis("Old synopsis + user")

        var incoming = story
        incoming.title = "Agent title"
        incoming.synopsis = "Agent synopsis"
        draft.applyExternalUpdate(incoming)

        // 用户正在输入时不打断本地文本。
        #expect(draft.synopsis == "Old synopsis + user")

        // 但落盘必须基于外部最新版本，不能把 Agent 的标题写回旧值。
        let saved = draft.storyToSave()
        #expect(saved.id == story.id)
        #expect(saved.title == "Agent title")
        #expect(saved.synopsis == "Old synopsis + user")

        // 保存回声不应再次触发同步覆盖。
        draft.markSaved(saved)
        draft.applyExternalUpdate(saved)
        #expect(draft.synopsis == "Old synopsis + user")
        #expect(!draft.hasUnsavedSynopsis)
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("StoryWriterViewModelTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
