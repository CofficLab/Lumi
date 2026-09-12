import Foundation
import KitAgentTool
import Testing

@testable import StoryWriterPlugin

@Suite(.serialized)
@MainActor
struct StoryWriterToolTests {
    @Test func publicToolsExposeConsistentSchemasDescriptionsAndRisks() {
        #expect(StoryWriterV2Tool.all.count == 12)
        for tool in StoryWriterV2Tool.all {
            let schema = tool.inputSchema(for: .english)
            #expect(schema["type"] as? String == "object")
            #expect(schema["additionalProperties"] as? Bool == false)
            #expect(tool.description(for: .english).contains(tool.name.replacingOccurrences(of: "_", with: " ")))
            #expect(tool.displayDescription(for: [:]) == tool.name.replacingOccurrences(of: "_", with: " "))
        }

        #expect(tool("list_stories").permissionRiskLevel(arguments: [:]).rawValue == "safe")
        #expect(tool("create_story").permissionRiskLevel(arguments: [:]).rawValue == "low")
        #expect(tool("delete_story").permissionRiskLevel(arguments: [:]).rawValue == "medium")
        #expect(Set(schemaProperties(for: "create_story")) == Set(["story_id", "title", "synopsis"]))
        #expect(schemaProperties(for: "list_chapters").contains("chapter_id"))
        #expect(!schemaProperties(for: "list_stories").contains("story_id"))
    }

    @Test func toolsValidateArgumentsAndSupportStoryChapterLifecycle() async throws {
        let directory = try makeTemporaryDirectory()
        defer {
            StoryWriterStorage.configureV2(directory: nil)
            try? FileManager.default.removeItem(at: directory)
        }

        let listStories = tool("list_stories")
        #expect(try await listStories.execute(arguments: [:]) == "Error: Story Writer storage is not available.")
        StoryWriterStorage.configureV2(directory: directory)
        #expect(try await listStories.execute(arguments: [:]).contains("No stories found"))
        #expect(try await tool("create_story").execute(arguments: [:]) == "Error: title is required")
        #expect(try await tool("get_story").execute(arguments: ["story_id": .init("not-a-uuid")]) == "Error: story not found")
        #expect(try await tool("delete_story").execute(arguments: [:]) == "Error: valid story_id is required")

        let createdStoryResult = try await tool("create_story").execute(arguments: [
            "title": .init("Clockwork Harbor"),
            "synopsis": .init("A map changes every midnight.")
        ])
        #expect(createdStoryResult.contains("Created story **Clockwork Harbor**"))
        let store = StoryStore(pluginDirectory: directory)
        guard let story = await store.loadAllStories().first else {
            Issue.record("create_story did not persist a story")
            return
        }
        #expect(story.synopsis == "A map changes every midnight.")
        #expect((try await listStories.execute(arguments: [:])).contains("Clockwork Harbor"))

        let storyID = story.id.uuidString
        #expect((try await tool("get_story").execute(arguments: ["story_id": .init(storyID)])).contains("A map changes every midnight."))
        #expect(try await tool("update_story").execute(arguments: [
            "story_id": .init(storyID), "title": .init("The Harbor Clock"), "synopsis": .init("The tide rewinds.")
        ]) == "✅ Updated story **The Harbor Clock**.")
        #expect(try await tool("get_story").execute(arguments: ["title": .init("The Harbor Clock")]).contains("The tide rewinds."))

        #expect(try await tool("list_chapters").execute(arguments: [:]) == "Error: valid story_id is required")
        #expect(try await tool("create_chapter").execute(arguments: ["story_id": .init("bad"), "title": .init("Missing")]).contains("valid story_id and title"))
        #expect(try await tool("create_chapter").execute(arguments: ["story_id": .init(UUID().uuidString), "title": .init("Orphan")]).contains("story may not exist"))
        let chapterResult = try await tool("create_chapter").execute(arguments: [
            "story_id": .init(storyID),
            "title": .init("Tide Table"),
            "content": .init("The harbor moved backward."),
            "target_word_count": .init(1200)
        ])
        #expect(chapterResult.contains("Created chapter **Tide Table**"))
        guard let chapter = await store.loadChapters(storyID: story.id).first else {
            Issue.record("create_chapter did not persist a chapter")
            return
        }
        #expect(chapter.content == "The harbor moved backward.")
        #expect(chapter.status == .inProgress)
        #expect(chapter.targetWordCount == 1200)

        let chapterID = chapter.id.uuidString
        #expect((try await tool("list_chapters").execute(arguments: ["story_id": .init(storyID)])).contains("Tide Table"))
        #expect((try await tool("get_chapter").execute(arguments: ["story_id": .init(storyID), "chapter_id": .init(chapterID)])).contains("The harbor moved backward."))
        #expect(try await tool("update_chapter").execute(arguments: [
            "story_id": .init(storyID), "chapter_id": .init(chapterID), "status": .init("invalid")
        ]) == "Error: invalid status")
        #expect(try await tool("update_chapter").execute(arguments: [
            "story_id": .init(storyID), "chapter_id": .init(chapterID), "title": .init("Rewinding"),
            "content": .init("The clock struck twelve."), "target_word_count": .init(1500), "status": .init("done")
        ]) == "✅ Updated chapter **Rewinding** (21 words).")
        #expect((await store.loadChapter(id: chapter.id, storyID: story.id))?.status == .done)

        let importedResult = try await tool("import_markdown_as_chapter").execute(arguments: [
            "story_id": .init(storyID), "title": .init("Imported"), "content": .init("From a Markdown file.")
        ])
        #expect(importedResult.contains("Created chapter **Imported**"))
        #expect((try await tool("export_story_as_markdown").execute(arguments: ["story_id": .init(storyID)])).contains("From a Markdown file."))
        #expect(try await tool("delete_chapter").execute(arguments: ["story_id": .init(storyID)]) == "Error: valid story_id and chapter_id are required")
        #expect(try await tool("delete_chapter").execute(arguments: ["story_id": .init(storyID), "chapter_id": .init(chapterID)]).contains("Deleted chapter"))
        #expect(try await tool("delete_story").execute(arguments: ["story_id": .init(storyID)]).contains("Deleted story"))
        #expect(try await listStories.execute(arguments: [:]).contains("No stories found"))
        #expect(try await tool("export_story_as_markdown").execute(arguments: ["story_id": .init(storyID)]) == "Error: story not found")
    }

    @Test func toolsReportUnavailableStorage() async throws {
        StoryWriterStorage.configureV2(directory: nil)
        #expect(try await tool("list_stories").execute(arguments: [:]) == "Error: Story Writer storage is not available.")
    }
}

@MainActor
private func schemaProperties(for name: String) -> [String] {
    let schema = tool(name).inputSchema(for: .english)
    let properties = schema["properties"] as? [String: Any] ?? [:]
    return Array(properties.keys)
}

@MainActor
private func tool(_ name: String) -> StoryWriterV2Tool {
    StoryWriterV2Tool.all.first { $0.name == name }!
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("StoryWriterToolTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
