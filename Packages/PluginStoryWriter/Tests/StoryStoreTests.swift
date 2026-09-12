import Foundation
import Testing

@testable import StoryWriterPlugin

struct StoryStoreTests {
    @Test func storyChapterAndCharacterCRUDPersistsRelationships() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StoryStore(pluginDirectory: directory)

        #expect(await store.loadAllStories().isEmpty)
        #expect(await store.loadStory(id: UUID()) == nil)

        var story = await store.createStory(title: "First draft")
        story.title = "The Quiet City"
        story.synopsis = "A city wakes up."
        await store.updateStory(story)

        guard let persistedStory = await store.loadStory(id: story.id) else {
            Issue.record("Updated story was not persisted")
            return
        }
        #expect(persistedStory.title == "The Quiet City")
        #expect(persistedStory.synopsis == "A city wakes up.")
        #expect(await store.loadAllStories().map(\.id) == [story.id])

        guard let firstChapter = await store.createChapter(storyID: story.id, title: "Arrival"),
              let importedChapter = await store.importMarkdownAsChapter(
                storyID: story.id,
                title: "The station",
                content: "Rain covered the platform."
              ),
              let character = await store.createCharacter(storyID: story.id, name: "Mina") else {
            Issue.record("Could not create story children")
            return
        }

        #expect(await store.loadChapters(storyID: story.id).map(\.id).count == 2)
        #expect(await store.loadCharacters(storyID: story.id).map(\.id) == [character.id])
        guard let relatedStory = await store.loadStory(id: story.id) else {
            Issue.record("Story disappeared after adding children")
            return
        }
        #expect(relatedStory.chapterIDs == [firstChapter.id, importedChapter.id])
        #expect(relatedStory.characterIDs == [character.id])

        var updatedChapter = importedChapter
        updatedChapter.title = "Platform"
        updatedChapter.content = "Rain covered the platform. Mina waited."
        updatedChapter.status = .inProgress
        updatedChapter.targetWordCount = 900
        await store.updateChapter(updatedChapter)
        let loadedChapter = await store.loadChapter(id: importedChapter.id, storyID: story.id)
        #expect(loadedChapter?.title == "Platform")
        #expect(loadedChapter?.content == updatedChapter.content)
        #expect(loadedChapter?.status == .inProgress)
        #expect(loadedChapter?.targetWordCount == 900)

        var updatedCharacter = character
        updatedCharacter.role = "Lead"
        updatedCharacter.personality = "Observant"
        updatedCharacter.notes = "Carries a blue notebook."
        await store.updateCharacter(updatedCharacter)
        let loadedCharacter = await store.loadCharacter(id: character.id, storyID: story.id)
        #expect(loadedCharacter?.role == "Lead")
        #expect(loadedCharacter?.personality == "Observant")
        #expect(loadedCharacter?.notes == "Carries a blue notebook.")

        await store.deleteChapter(id: firstChapter.id, storyID: story.id)
        await store.deleteCharacter(id: character.id, storyID: story.id)
        #expect(await store.loadChapter(id: firstChapter.id, storyID: story.id) == nil)
        #expect(await store.loadCharacter(id: character.id, storyID: story.id) == nil)
        guard let afterDeletingChildren = await store.loadStory(id: story.id) else {
            Issue.record("Story disappeared after deleting children")
            return
        }
        #expect(afterDeletingChildren.chapterIDs == [importedChapter.id])
        #expect(afterDeletingChildren.characterIDs.isEmpty)

        await store.deleteStory(id: story.id)
        #expect(await store.loadStory(id: story.id) == nil)
        #expect(await store.loadAllStories().isEmpty)
    }

    @Test func storyListUsesUpdatedTimeAndIgnoresMalformedRecords() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StoryStore(pluginDirectory: directory)

        let olderStory = Story(
            title: "Older",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let newerStory = Story(
            title: "Newer",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let storiesDirectory = directory.appendingPathComponent("stories")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        for story in [olderStory, newerStory] {
            let storyDirectory = storiesDirectory.appendingPathComponent(story.id.uuidString)
            try FileManager.default.createDirectory(at: storyDirectory, withIntermediateDirectories: true)
            try encoder.encode(story).write(to: storyDirectory.appendingPathComponent("story.json"))
        }

        let malformedStoryDirectory = directory
            .appendingPathComponent("stories")
            .appendingPathComponent("malformed")
        try FileManager.default.createDirectory(at: malformedStoryDirectory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: malformedStoryDirectory.appendingPathComponent("story.json"))

        let loadedStories = await store.loadAllStories()
        #expect(loadedStories.map(\.id) == [newerStory.id, olderStory.id])
        #expect(await store.loadStory(id: UUID()) == nil)
    }

    @Test func markdownExportIncludesSynopsisChaptersAndOptionalCharacterDetails() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StoryStore(pluginDirectory: directory)
        var story = await store.createStory(title: "Paper Moon")
        story.synopsis = "A map points home."
        await store.updateStory(story)

        _ = await store.importMarkdownAsChapter(
            storyID: story.id,
            title: "First light",
            content: "The map began to glow."
        )
        _ = await store.createCharacter(storyID: story.id, name: "Iris")
        guard let detailedCharacter = await store.createCharacter(storyID: story.id, name: "Noah") else {
            Issue.record("Could not create character")
            return
        }
        var character = detailedCharacter
        character.role = "Guide"
        character.personality = "Patient"
        character.notes = "Knows the old road."
        await store.updateCharacter(character)

        let markdown = await store.exportStoryAsMarkdown(storyID: story.id)
        #expect(markdown?.contains("# Paper Moon") == true)
        #expect(markdown?.contains("## Synopsis\n\nA map points home.") == true)
        #expect(markdown?.contains("## First light\n\nThe map began to glow.") == true)
        #expect(markdown?.contains("### Iris\n") == true)
        #expect(markdown?.contains("### Noah\n**Role:** Guide\n**Personality:** Patient\n**Notes:** Knows the old road.") == true)
        #expect(await store.exportStoryAsMarkdown(storyID: UUID()) == nil)
    }

    @Test func modelsCountNonWhitespaceContentAndExposeAllChapterStates() {
        let chapter = Chapter(storyID: UUID(), title: "Words", content: "你好 world\n")
        #expect(chapter.wordCount == 7)
        #expect(ChapterStatus.allCases == [.draft, .inProgress, .done])
        #expect(ChapterStatus.draft.displayName == "Draft")
        #expect(ChapterStatus.inProgress.displayName == "In Progress")
        #expect(ChapterStatus.done.displayName == "Done")
        #expect(StoryWriterNodeKind.allCases == [.story, .chapter, .character])
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("StoryWriterTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
