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

    @Test func deletingMissingStoryOrChapterReportsNotFound() async throws {
        let directory = try makeTemporaryDirectory()
        defer {
            StoryWriterStorage.configureV2(directory: nil)
            try? FileManager.default.removeItem(at: directory)
        }
        StoryWriterStorage.configureV2(directory: directory)

        let missing = UUID().uuidString
        await #expect(throws: ToolExecutionError.self) {
            try await tool("delete_story").execute(arguments: ["story_id": .init(missing)])
        }

        _ = try await tool("create_story").execute(arguments: ["title": .init("Keep")])
        let store = StoryStore(pluginDirectory: directory)
        guard let story = await store.loadAllStories().first else {
            Issue.record("create_story did not persist a story")
            return
        }
        let storyID = story.id.uuidString

        await #expect(throws: ToolExecutionError.self) {
            try await tool("delete_chapter").execute(arguments: [
                "story_id": .init(storyID),
                "chapter_id": .init(missing)
            ])
        }
        #expect(await store.loadStory(id: story.id) != nil)

        #expect(try await tool("delete_story").execute(arguments: ["story_id": .init(storyID)]) == "🗑️ Deleted story \(storyID).")
        #expect(await store.loadStory(id: story.id) == nil)
    }

    @Test func listingChaptersDistinguishesMissingStoryFromEmptyStory() async throws {
        let directory = try makeTemporaryDirectory()
        defer {
            StoryWriterStorage.configureV2(directory: nil)
            try? FileManager.default.removeItem(at: directory)
        }
        StoryWriterStorage.configureV2(directory: directory)

        // 回归 #1064：父故事不存在时不能返回「暂无章节」的成功文案。
        await #expect(throws: ToolExecutionError.self) {
            try await tool("list_chapters").execute(arguments: ["story_id": .init(UUID().uuidString)])
        }

        let storyOutput = try await tool("create_story").execute(arguments: ["title": .init("Empty Shelf")])
        let storyID = try #require(firstUUID(in: storyOutput))
        #expect(try await tool("list_chapters").execute(arguments: ["story_id": .init(storyID)]) == "No chapters in this story yet.")

        _ = try await tool("delete_story").execute(arguments: ["story_id": .init(storyID)])
        await #expect(throws: ToolExecutionError.self) {
            try await tool("list_chapters").execute(arguments: ["story_id": .init(storyID)])
        }
    }

    @Test func toolsValidateArgumentsAndSupportStoryChapterLifecycle() async throws {
        let directory = try makeTemporaryDirectory()
        defer {
            StoryWriterStorage.configureV2(directory: nil)
            try? FileManager.default.removeItem(at: directory)
        }

        let listStories = tool("list_stories")
        await #expect(throws: ToolExecutionError.self) {
            try await listStories.execute(arguments: [:])
        }
        StoryWriterStorage.configureV2(directory: directory)
        #expect(try await listStories.execute(arguments: [:]).contains("No stories found"))
        await #expect(throws: ToolExecutionError.self) {
            try await tool("create_story").execute(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            try await tool("get_story").execute(arguments: ["story_id": .init("not-a-uuid")])
        }
        await #expect(throws: ToolExecutionError.self) {
            try await tool("delete_story").execute(arguments: [:])
        }

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

        await #expect(throws: ToolExecutionError.self) {
            try await tool("list_chapters").execute(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            try await tool("create_chapter").execute(arguments: ["story_id": .init("bad"), "title": .init("Missing")])
        }
        await #expect(throws: ToolExecutionError.self) {
            try await tool("create_chapter").execute(arguments: ["story_id": .init(UUID().uuidString), "title": .init("Orphan")])
        }
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
        await #expect(throws: ToolExecutionError.self) {
            try await tool("update_chapter").execute(arguments: [
                "story_id": .init(storyID), "chapter_id": .init(chapterID), "status": .init("invalid")
            ])
        }
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
        await #expect(throws: ToolExecutionError.self) {
            try await tool("delete_chapter").execute(arguments: ["story_id": .init(storyID)])
        }
        #expect(try await tool("delete_chapter").execute(arguments: ["story_id": .init(storyID), "chapter_id": .init(chapterID)]).contains("Deleted chapter"))
        #expect(try await tool("delete_story").execute(arguments: ["story_id": .init(storyID)]).contains("Deleted story"))
        #expect(try await listStories.execute(arguments: [:]).contains("No stories found"))
        await #expect(throws: ToolExecutionError.self) {
            try await tool("export_story_as_markdown").execute(arguments: ["story_id": .init(storyID)])
        }
    }

    @Test func toolsReportUnavailableStorage() async throws {
        StoryWriterStorage.configureV2(directory: nil)
        await #expect(throws: ToolExecutionError.self) {
            try await tool("list_stories").execute(arguments: [:])
        }
    }

    @Test func validationFailuresThrowThroughExecuteResult() async throws {
        let directory = try makeTemporaryDirectory()
        defer {
            StoryWriterStorage.configureV2(directory: nil)
            try? FileManager.default.removeItem(at: directory)
        }
        StoryWriterStorage.configureV2(directory: directory)

        // 回归：失败曾经只返回 "Error: ..." 字符串，默认 executeResult 仍产出
        // isError == false，工具调用会被当成成功。现在必须一路抛到宿主。
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool("create_story").executeResult(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool("get_story").executeResult(arguments: ["story_id": .init(UUID().uuidString)])
        }
    }

    @Test func chapterStatusRoundTripsThroughReadAndUpdate() async throws {
        let directory = try makeTemporaryDirectory()
        defer {
            StoryWriterStorage.configureV2(directory: nil)
            try? FileManager.default.removeItem(at: directory)
        }
        StoryWriterStorage.configureV2(directory: directory)

        let storyOutput = try await tool("create_story").execute(arguments: ["title": .init("Roundtrip")])
        let storyID = try #require(firstUUID(in: storyOutput))
        _ = try await tool("create_chapter").execute(arguments: [
            "story_id": .init(storyID), "title": .init("One"), "content": .init("Hello"),
        ])
        let listOutput = try await tool("list_chapters").execute(arguments: ["story_id": .init(storyID)])
        let chapterID = try #require(firstUUID(in: listOutput))

        let read = try await tool("get_chapter").execute(arguments: [
            "story_id": .init(storyID), "chapter_id": .init(chapterID),
        ])
        #expect(read.contains("status: in_progress"), "读取应输出公开 schema 的令牌")
        #expect(!read.contains("inProgress"), "读取不应泄漏 Swift rawValue")

        // 按 get_chapter 的输出原样读改写，必须被 update_chapter 接受。
        let statusToken = try #require(
            read.components(separatedBy: "status: ").dropFirst().first?
                .components(separatedBy: "\n").first
        )
        let updated = try await tool("update_chapter").execute(arguments: [
            "story_id": .init(storyID),
            "chapter_id": .init(chapterID),
            "status": .init(statusToken),
            "title": .init("Renamed"),
        ])
        #expect(updated.contains("Renamed"))

        let reread = try await tool("get_chapter").execute(arguments: [
            "story_id": .init(storyID), "chapter_id": .init(chapterID),
        ])
        #expect(reread.contains("status: in_progress"))

        // 历史版本输出过的 rawValue 仍被接受，避免旧会话中途失败。
        _ = try await tool("update_chapter").execute(arguments: [
            "story_id": .init(storyID),
            "chapter_id": .init(chapterID),
            "status": .init("inProgress"),
        ])
    }
}

private func firstUUID(in text: String) -> String? {
    let pattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          let matchRange = Range(match.range, in: text) else { return nil }
    return String(text[matchRange])
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
