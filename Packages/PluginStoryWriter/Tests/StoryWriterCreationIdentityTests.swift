import Foundation
import Testing

@testable import StoryWriterPlugin

/// 故事创建类请求的**回合身份隔离**回归测试（#432）。
///
/// ## 复现的缺陷
///
/// `createChapter` / `importMarkdownAsChapter` / `createCharacter` 先捕获
/// `currentStoryID`，`await store.…` 之后**无条件**把结果追加进共享的
/// `chapters` / `characters` 并改写 `selectedNodeID/Kind`。await 期间用户
/// 切到故事 B 时，A 的创建结果晚到，会污染 B 的大纲（出现不属于 B 的
/// 章节/角色）并把选择指向 B 中不存在的节点。
///
/// 修复：`loadStoryContent` 每次装载故事时递增 `storyGeneration`；三个
/// 创建方法在 await 前捕获代次，写回共享状态前比对
/// `storyGeneration == generation && currentStoryID == storyID`，不匹配
/// 只返回已创建对象（磁盘操作仍归属原故事），不改内存列表与选择。
///
/// ## 观测手段
///
/// 通过 `StoryWriting` 注入一个门闩 stub：创建调用先停在 continuation，
/// 测试在此期间切换到故事 B，再放行创建，构造确定性的「旧请求晚到」。
@Suite("StoryWriter 创建请求的故事身份隔离")
@MainActor
struct StoryWriterCreationIdentityTests {

    // MARK: - 晚到的章节创建不得污染新故事

    @Test("切换故事后晚到的章节创建只落盘原故事，不改新故事大纲与选择（回归 #432）")
    func lateChapterCreationDoesNotPolluteSwitchedStory() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let base = StoryStore(pluginDirectory: directory)
        let stub = GatedStoryStore(base: base)
        let viewModel = StoryWriterViewModel(store: stub)

        let storyA = await viewModel.createStory(title: "A")
        let storyB = await viewModel.createStory(title: "B")
        await viewModel.selectStory(id: storyA.id)

        await stub.holdNextCreation()
        let task = Task { await viewModel.createChapter(title: "Late") }
        await waitUntil { await stub.isWaitingAtGate }

        // 创建仍挂在门闩上时切到 B。
        await viewModel.selectStory(id: storyB.id)
        await stub.releaseCreation()
        let chapter = await task.value

        #expect(chapter != nil, "原故事的磁盘创建应当完成")
        #expect(chapter?.storyID == storyA.id)
        #expect(viewModel.currentStoryID == storyB.id)
        #expect(viewModel.chapters.isEmpty, "B 的大纲不得出现 A 的晚到章节")
        #expect(viewModel.selectedNodeID == storyB.id, "选择不得被指向 B 中不存在的章节")
        #expect(viewModel.selectedNodeKind == .story)

        let diskChapters = await base.loadChapters(storyID: storyA.id)
        #expect(diskChapters.map(\.id) == [chapter?.id], "章节必须真实落盘在原故事 A 下")

        // 切回 A 时晚到创建的章节应当可见。
        await viewModel.selectStory(id: storyA.id)
        #expect(viewModel.chapters.map(\.id) == [chapter?.id])
    }

    // MARK: - 晚到的 Markdown 导入不得污染新故事

    @Test("切换故事后晚到的 Markdown 导入不进入新故事章节列表与字数（回归 #432）")
    func lateMarkdownImportDoesNotPolluteSwitchedStory() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let base = StoryStore(pluginDirectory: directory)
        let stub = GatedStoryStore(base: base)
        let viewModel = StoryWriterViewModel(store: stub)

        let storyA = await viewModel.createStory(title: "A")
        let storyB = await viewModel.createStory(title: "B")
        await viewModel.selectStory(id: storyA.id)

        await stub.holdNextCreation()
        let task = Task {
            await viewModel.importMarkdownAsChapter(title: "Imported", content: "late import body")
        }
        await waitUntil { await stub.isWaitingAtGate }

        await viewModel.selectStory(id: storyB.id)
        await stub.releaseCreation()
        let chapter = await task.value

        #expect(chapter?.storyID == storyA.id)
        #expect(viewModel.currentStoryID == storyB.id)
        #expect(viewModel.chapters.isEmpty, "B 不得收到 A 的晚到导入章节")
        #expect(viewModel.totalWordCount == 0, "B 的总字数不得被 A 的导入正文抬高")
        #expect(viewModel.selectedNodeID == storyB.id)
        #expect(viewModel.selectedNodeKind == .story)

        let diskChapters = await base.loadChapters(storyID: storyA.id)
        #expect(diskChapters.map(\.id) == [chapter?.id])
        #expect(diskChapters.first?.content == "late import body")
    }

    // MARK: - 晚到的角色创建不得污染新故事

    @Test("切换故事后晚到的角色创建只落盘原故事，不改新故事角色列表与选择（回归 #432）")
    func lateCharacterCreationDoesNotPolluteSwitchedStory() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let base = StoryStore(pluginDirectory: directory)
        let stub = GatedStoryStore(base: base)
        let viewModel = StoryWriterViewModel(store: stub)

        let storyA = await viewModel.createStory(title: "A")
        let storyB = await viewModel.createStory(title: "B")
        await viewModel.selectStory(id: storyA.id)

        await stub.holdNextCreation()
        let task = Task { await viewModel.createCharacter(name: "Late Rin") }
        await waitUntil { await stub.isWaitingAtGate }

        await viewModel.selectStory(id: storyB.id)
        await stub.releaseCreation()
        let character = await task.value

        #expect(character?.storyID == storyA.id)
        #expect(viewModel.currentStoryID == storyB.id)
        #expect(viewModel.characters.isEmpty, "B 的角色列表不得出现 A 的晚到角色")
        #expect(viewModel.selectedNodeID == storyB.id, "选择不得被指向 B 中不存在的角色")
        #expect(viewModel.selectedNodeKind == .story)

        let diskCharacters = await base.loadCharacters(storyID: storyA.id)
        #expect(diskCharacters.map(\.id) == [character?.id])
    }

    // MARK: - 未切换故事时创建仍正常追加并选中

    @Test("故事未切换时创建章节/角色仍追加进列表并选中（回归 #432）")
    func creationWithoutStorySwitchStillAppendsAndSelects() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stub = GatedStoryStore(base: StoryStore(pluginDirectory: directory))
        let viewModel = StoryWriterViewModel(store: stub)

        let story = await viewModel.createStory(title: "A")
        guard let chapter = await viewModel.createChapter(title: "Opening"),
              let character = await viewModel.createCharacter(name: "Rin") else {
            Issue.record("Could not create story content")
            return
        }

        #expect(viewModel.currentStoryID == story.id)
        #expect(viewModel.chapters.map(\.id) == [chapter.id])
        #expect(viewModel.characters.map(\.id) == [character.id])
        #expect(viewModel.selectedNodeID == character.id)
        #expect(viewModel.selectedNodeKind == .character)
    }
}

// MARK: - 门闩 stub

/// 包装真实 `StoryStore`，可把下一次创建类调用（章节/导入/角色）停在
/// continuation 上，供测试在挂起期间切换故事，构造确定性的晚到请求。
/// actor 在 continuation 处挂起时可重入，其余转发调用不受阻塞。
private actor GatedStoryStore: StoryWriting {
    let base: StoryStore
    private var holdNext = false
    private var gate: CheckedContinuation<Void, Never>?
    private(set) var isWaitingAtGate = false

    init(base: StoryStore) {
        self.base = base
    }

    func holdNextCreation() {
        holdNext = true
    }

    func releaseCreation() {
        holdNext = false
        isWaitingAtGate = false
        gate?.resume()
        gate = nil
    }

    private func waitForGateIfNeeded() async {
        guard holdNext else { return }
        holdNext = false
        await withCheckedContinuation { continuation in
            isWaitingAtGate = true
            gate = continuation
        }
    }

    func createChapter(storyID: UUID, title: String) async throws -> Chapter? {
        await waitForGateIfNeeded()
        return try await base.createChapter(storyID: storyID, title: title)
    }

    func importMarkdownAsChapter(storyID: UUID, title: String, content: String) async throws -> Chapter? {
        await waitForGateIfNeeded()
        return try await base.importMarkdownAsChapter(storyID: storyID, title: title, content: content)
    }

    func createCharacter(storyID: UUID, name: String) async throws -> Character? {
        await waitForGateIfNeeded()
        return try await base.createCharacter(storyID: storyID, name: name)
    }

    func loadAllStories() async -> [Story] { await base.loadAllStories() }
    func createStory(title: String) async throws -> Story { try await base.createStory(title: title) }
    func updateStory(_ story: Story) async throws { try await base.updateStory(story) }
    @discardableResult
    func deleteStory(id: UUID) async -> Bool { await base.deleteStory(id: id) }
    func loadChapters(storyID: UUID) async -> [Chapter] { await base.loadChapters(storyID: storyID) }
    func updateChapter(_ chapter: Chapter) async throws { try await base.updateChapter(chapter) }
    @discardableResult
    func deleteChapter(id: UUID, storyID: UUID) async throws -> Bool { try await base.deleteChapter(id: id, storyID: storyID) }
    func loadCharacters(storyID: UUID) async -> [Character] { await base.loadCharacters(storyID: storyID) }
    func updateCharacter(_ character: Character) async throws { try await base.updateCharacter(character) }
    func deleteCharacter(id: UUID, storyID: UUID) async throws { try await base.deleteCharacter(id: id, storyID: storyID) }
    func exportStoryAsMarkdown(storyID: UUID) async -> String? { await base.exportStoryAsMarkdown(storyID: storyID) }
}

// MARK: - 辅助

@MainActor
private func waitUntil(timeout: Duration = .seconds(3), _ condition: () async -> Bool) async {
    let deadline = ContinuousClock.now + timeout
    while !(await condition()) {
        if ContinuousClock.now >= deadline {
            Issue.record("Timed out waiting for condition")
            return
        }
        await Task.yield()
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("StoryWriterCreationIdentityTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}