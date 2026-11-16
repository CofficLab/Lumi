import Foundation
import Testing

@testable import StoryWriterPlugin

/// 回归 #431：StoryStore 的保存失败必须抛出，且不得留下悬空引用。
///
/// 旧实现用 `try?` 吞掉目录创建/编码/写入错误，createChapter 即便章节文件
/// 没写成也照样把 ID 追加进 story.json，工具还回报「Created chapter」。
/// 修复后：保存失败抛出；章节文件与 story 引用作为一个一致操作处理，
/// 引用写失败时回滚已落盘的章节文件。
struct StoryStoreSaveFailureTests {

    // MARK: - Helpers

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoryWriterSaveFailure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func storyDirectory(_ root: URL, _ id: UUID) -> URL {
        root.appendingPathComponent("stories").appendingPathComponent(id.uuidString)
    }

    /// 把某个本应是目录的路径占成普通文件，使后续 createDirectory 必然失败。
    private func occupyWithFile(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data("occupied".utf8).write(to: url, options: .atomic)
    }

    #if os(macOS)
    private func setImmutable(_ url: URL, _ immutable: Bool) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
        process.arguments = [immutable ? "uchg" : "nouchg", url.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
    #endif

    // MARK: - 创建失败不得留下悬空 ID

    @Test("chapters 不可写时 createChapter 抛出，story 不残留章节 ID")
    func createChapterThrowsAndLeavesNoDanglingID() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = StoryStore(pluginDirectory: root)

        let story = try await store.createStory(title: "Draft")
        try occupyWithFile(storyDirectory(root, story.id).appendingPathComponent("chapters"))

        await #expect(throws: (any Error).self) {
            _ = try await store.createChapter(storyID: story.id, title: "Arrival")
        }

        let reloaded = await store.loadStory(id: story.id)
        #expect(reloaded?.chapterIDs.isEmpty == true)
        #expect(await store.loadChapters(storyID: story.id).isEmpty)
    }

    @Test("characters 不可写时 createCharacter 抛出，story 不残留角色 ID")
    func createCharacterThrowsAndLeavesNoDanglingID() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = StoryStore(pluginDirectory: root)

        let story = try await store.createStory(title: "Draft")
        try occupyWithFile(storyDirectory(root, story.id).appendingPathComponent("characters"))

        await #expect(throws: (any Error).self) {
            _ = try await store.createCharacter(storyID: story.id, name: "Mina")
        }

        let reloaded = await store.loadStory(id: story.id)
        #expect(reloaded?.characterIDs.isEmpty == true)
        #expect(await store.loadCharacters(storyID: story.id).isEmpty)
    }

    @Test("chapters 不可写时 importMarkdownAsChapter 抛出，story 不残留章节 ID")
    func importMarkdownThrowsAndLeavesNoDanglingID() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = StoryStore(pluginDirectory: root)

        let story = try await store.createStory(title: "Draft")
        try occupyWithFile(storyDirectory(root, story.id).appendingPathComponent("chapters"))

        await #expect(throws: (any Error).self) {
            _ = try await store.importMarkdownAsChapter(storyID: story.id, title: "Station", content: "Rain.")
        }

        let reloaded = await store.loadStory(id: story.id)
        #expect(reloaded?.chapterIDs.isEmpty == true)
    }

    @Test("stories 目录不可写时 createStory 抛出")
    func createStoryThrowsWhenStoriesDirUnwritable() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = StoryStore(pluginDirectory: root)

        try occupyWithFile(root.appendingPathComponent("stories"))

        await #expect(throws: (any Error).self) {
            _ = try await store.createStory(title: "Draft")
        }
        #expect(await store.loadAllStories().isEmpty)
    }

    // MARK: - 引用写失败时回滚已落盘的实体文件（仅 macOS）

    #if os(macOS)
    @Test("story 引用写失败时 createChapter 回滚章节文件，二者保持一致")
    func createChapterRollsBackChapterFileWhenStorySaveFails() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = StoryStore(pluginDirectory: root)

        let story = try await store.createStory(title: "Draft")
        let storyFile = storyDirectory(root, story.id).appendingPathComponent("story.json")
        // story.json 可读（loadStory 成功）但不可写（原子 rename 被拒）。
        try setImmutable(storyFile, true)
        defer { try? setImmutable(storyFile, false) }

        await #expect(throws: (any Error).self) {
            _ = try await store.createChapter(storyID: story.id, title: "Arrival")
        }

        // 章节文件已先落盘，引用写失败后必须被回滚删除。
        #expect(await store.loadChapters(storyID: story.id).isEmpty)
        let chaptersDir = storyDirectory(root, story.id).appendingPathComponent("chapters")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: chaptersDir.path)) ?? []
        #expect(files.isEmpty)
        // story.json 未被改动，仍不引用任何章节。
        #expect(await store.loadStory(id: story.id)?.chapterIDs.isEmpty == true)
    }

    @Test("章节文件不可写时 updateChapter 抛出，不再伪装成功")
    func updateChapterThrowsWhenChapterFileUnwritable() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = StoryStore(pluginDirectory: root)

        let story = try await store.createStory(title: "Draft")
        guard let chapter = try await store.createChapter(storyID: story.id, title: "Arrival") else {
            Issue.record("could not create chapter")
            return
        }
        let chapterFile = storyDirectory(root, story.id)
            .appendingPathComponent("chapters")
            .appendingPathComponent("\(chapter.id.uuidString).json")
        try setImmutable(chapterFile, true)
        defer { try? setImmutable(chapterFile, false) }

        var updated = chapter
        updated.content = "New body"
        await #expect(throws: (any Error).self) {
            try await store.updateChapter(updated)
        }
    }
    #endif
}