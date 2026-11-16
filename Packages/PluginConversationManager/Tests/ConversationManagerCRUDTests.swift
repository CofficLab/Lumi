import Foundation
import KitAgentTool
import ProviderConversation
import ProviderToolManager
import Testing
@testable import PluginConversationManager

@MainActor
@Suite(.serialized)
struct ConversationManagerCRUDTests {
    @Test func creationInheritsGlobalPreferencesAndKeepsChildOutOfRootCache() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationCreationTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        manager.setGlobalVerbosity(.brief)
        manager.setGlobalReasoningEffort(.low)
        manager.setGlobalAutomationLevel(.autonomous)
        manager.setGlobalLanguage(.english)
        var events: [ConversationEvent] = []
        let handle = manager.addConversationObserver { events.append($0) }
        defer { handle.cancel() }

        let rootID = try manager.createConversation(
            title: "  Root conversation  ",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        let root = try #require(manager.conversations.first)
        #expect(root.id == rootID)
        #expect(root.title == "Root conversation")
        #expect(root.verbosity == .brief)
        #expect(root.reasoningEffort == .low)
        #expect(root.automationLevel == .autonomous)
        #expect(root.language == .english)
        #expect(manager.selectedConversationID == rootID)
        #expect(manager.currentTitle == "Root conversation")

        let childID = try manager.createConversation(
            title: "Sub-agent",
            projectPath: nil,
            providerID: nil,
            modelName: nil,
            parentConversationID: rootID
        )
        #expect(manager.conversations.map(\.id) == [rootID])
        #expect(manager.selectedConversationID == rootID)
        #expect(events.contains(.created(rootID)))
        #expect(!events.contains(.created(childID)))

        try await Task.sleep(for: .milliseconds(20))
    }

    /// 回归 #541：等待落库的创建接口返回时，会话必须已经能从库里读到。
    @Test func createAndWaitPersistsBeforeReturningAndCachesRoot() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationCreateAndWait-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)

        let id = try await manager.createConversationAndWait(
            title: "Waited",
            projectPath: nil,
            modelID: nil,
            parentConversationID: nil
        )

        // 不 sleep：返回即代表已落库。
        let stored = await store.fetchConversation(id: id)
        #expect(stored?.title == "Waited")
        #expect(manager.conversations.contains(where: { $0.id == id }))
        #expect(manager.selectedConversationID == id)
    }

    @Test func selectionTitleActivityAndDeletionUpdateCachedStateAndEvents() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationCRUDTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConversationManager(store: nil, dataDirectory: directory)
        let firstID = UUID()
        let secondID = UUID()
        manager.conversations = [
            ConversationSummary(id: firstID, title: "First"),
            ConversationSummary(id: secondID, title: "Second"),
        ]
        var selectedIDs: [UUID?] = []
        var selectedEventTitles: [String] = []
        var events: [ConversationEvent] = []
        let selectedHandle = manager.addSelectedConversationObserver { selectedIDs.append($0) }
        let eventHandle = manager.addConversationObserver { event in
            events.append(event)
            if case .selected = event {
                selectedEventTitles.append(manager.currentTitle)
            }
        }
        defer {
            selectedHandle.cancel()
            eventHandle.cancel()
        }

        manager.selectConversation(id: firstID)
        #expect(manager.currentTitle == "First")
        #expect(selectedIDs == [firstID])
        #expect(selectedEventTitles == ["First"])

        #expect(manager.updateConversationTitle("   ", for: firstID))
        #expect(manager.conversations.first(where: { $0.id == firstID })?.title == nil)
        #expect(manager.currentTitle == "Untitled")
        #expect(!manager.updateConversationTitle("missing", for: UUID()))
        #expect(manager.updateConversationTitle("Restored title", for: firstID))
        #expect(manager.currentTitle == "Restored title")

        let messageDate = Date(timeIntervalSince1970: 2_000_000_000)
        manager.markConversationActive(id: secondID, messageDate: messageDate)
        #expect(manager.conversations.first(where: { $0.id == secondID })?.lastMessageAt == messageDate)
        #expect(manager.sortedConversations.first?.id == secondID)

        manager.selectConversation(id: secondID)
        #expect(selectedEventTitles == ["First", "Second"])
        manager.deleteConversation(id: secondID)
        #expect(manager.conversations.map(\.id) == [firstID])
        #expect(manager.selectedConversationID == firstID)
        #expect(manager.currentTitle == "Restored title")
        manager.deleteConversation(id: UUID())
        #expect(manager.conversations.map(\.id) == [firstID])
        #expect(!manager.isSending(for: firstID))
        #expect(events.contains(.updated(firstID)))
        #expect(events.contains(.markedActive(secondID)))
        #expect(events.contains(.deleted(secondID)))

        try await Task.sleep(for: .milliseconds(20))
    }

    /// 回归 #771：父会话删除时，子会话也会被连带删掉，观察者（例如
    /// GoalTask）必须收到子会话的 `.deleted`，否则子会话的 Goals 会残留。
    @Test func deletingRootNotifiesDescendantConversations() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationDescendantDelete-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)

        var events: [ConversationEvent] = []
        let handle = manager.addConversationObserver { events.append($0) }
        defer { handle.cancel() }

        let rootID = try await manager.createConversationAndWait(
            title: "Root",
            projectPath: nil,
            modelID: nil,
            parentConversationID: nil
        )
        let childID = try await manager.createConversationAndWait(
            title: "Child",
            projectPath: nil,
            modelID: nil,
            parentConversationID: rootID
        )

        manager.deleteConversation(id: rootID)
        for _ in 0..<100 where !events.contains(.deleted(childID)) {
            try await Task.sleep(for: .milliseconds(20))
        }

        // `.deleted` 在持久化删除之前发出；等数据库行真正消失再清理临时目录，
        // 否则 defer 删库时后台 Task 仍在 fault，会触发 CoreData I/O 崩溃。
        var rootRemaining = await store.fetchConversation(id: rootID)
        var childRemaining = await store.fetchConversation(id: childID)
        for _ in 0..<100 where rootRemaining != nil || childRemaining != nil {
            try await Task.sleep(for: .milliseconds(20))
            rootRemaining = await store.fetchConversation(id: rootID)
            childRemaining = await store.fetchConversation(id: childID)
        }

        #expect(events.contains(.deleted(rootID)))
        #expect(events.contains(.deleted(childID)))
        #expect(rootRemaining == nil)
        #expect(childRemaining == nil)
    }

    /// 回归 #950：等待落盘的标题更新必须在返回前完成数据库写入。
    @Test func updateConversationTitleAndWaitPersistsBeforeReturning() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationTitleAndWait-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)
        let id = try await manager.createConversationAndWait(
            title: "Old title",
            projectPath: nil,
            modelID: nil,
            parentConversationID: nil
        )

        // 不 sleep：返回即代表已落库。
        let updated = await manager.updateConversationTitleAndWait("  New title  ", for: id)

        #expect(updated)
        #expect(manager.conversations.first(where: { $0.id == id })?.title == "New title")
        #expect(manager.currentTitle == "New title")
        let stored = await store.fetchConversation(id: id)
        #expect(stored?.title == "New title")
    }

    /// 回归 #950：数据库保存失败时不得发布内存/UI 新标题，也不得报告成功。
    @Test func updateConversationTitleAndWaitLeavesMemoryUntouchedWhenPersistFails() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationTitleFailure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)
        let id = try await manager.createConversationAndWait(
            title: "Stored title",
            projectPath: nil,
            modelID: nil,
            parentConversationID: nil
        )
        // 绕过管理器删掉库行，制造 store.updateTitle 返回 false 的落盘失败。
        let deleted = await store.deleteConversations(ids: [id])
        #expect(deleted)

        var events: [ConversationEvent] = []
        let handle = manager.addConversationObserver { events.append($0) }
        defer { handle.cancel() }

        let updated = await manager.updateConversationTitleAndWait("Should not apply", for: id)

        #expect(!updated)
        #expect(manager.conversations.first(where: { $0.id == id })?.title == "Stored title")
        #expect(manager.currentTitle == "Stored title")
        #expect(!events.contains(.updated(id)))
    }

    /// 回归 #897：批量清理的返回值必须与查询口径一致（顶层会话），
    /// 不能把连带删除的子 Agent 会话也计入，否则统计面板会出现
    /// 「清理前 1 条、清理后显示 3 条」的口径跳变。
    @Test func bulkDeletionReturnsTopLevelTargetsNotCascadedChildren() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationBulkDelete-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)

        let now = Date()
        let parent = UUID()
        let child1 = UUID()
        let child2 = UUID()
        let recent = UUID()
        try await store.createConversation(
            id: parent, title: "parent", createdAt: now.addingTimeInterval(-86_400 * 10)
        )
        try await store.createConversation(
            id: child1, title: "child 1",
            createdAt: now.addingTimeInterval(-86_400 * 9),
            parentConversationID: parent
        )
        try await store.createConversation(
            id: child2, title: "child 2",
            createdAt: now.addingTimeInterval(-86_400 * 9),
            parentConversationID: parent
        )
        try await store.createConversation(id: recent, title: "recent", createdAt: now)

        let cutoff = now.addingTimeInterval(-86_400)
        let deleted = await manager.deleteConversations(
            createdBefore: cutoff,
            projectPath: nil,
            includingChildConversations: false
        )

        // 顶层口径只有 parent；返回值必须与清理前的计数一致。
        #expect(deleted == [parent])
        // 子会话仍然被连带删除，只剩未过期的 recent。
        let remaining = await store.conversationIDs(
            createdBefore: Date().addingTimeInterval(86_400 * 365),
            includingChildConversations: true
        )
        #expect(remaining == [recent])
    }

    /// 回归 #801：单条删除落库失败时，乐观移除必须还原，内存不得与数据库分叉，
    /// 选中项与标题也要回到删除前的状态（与 #950 的落盘失败模拟一致）。
    @Test func singleDeletionRestoresMemoryWhenPersistFails() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationSingleDeleteFailure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)
        let id = try await manager.createConversationAndWait(
            title: "Doomed",
            projectPath: nil,
            modelID: nil,
            parentConversationID: nil
        )
        // 绕过管理器删掉库行，使 store.deleteConversations  fetch 不到模型而返回 false。
        #expect(await store.deleteConversations(ids: [id]))
        #expect(manager.conversations.contains { $0.id == id })
        #expect(manager.selectedConversationID == id)

        manager.deleteConversation(id: id)
        // 乐观移除立即生效。
        #expect(!manager.conversations.contains { $0.id == id })

        // 等后台 Task 落库失败并还原。
        for _ in 0..<100 where !manager.conversations.contains(where: { $0.id == id }) {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(manager.conversations.contains { $0.id == id })
        #expect(manager.selectedConversationID == id)
        #expect(manager.currentTitle == "Doomed")
    }

    /// 回归 #801：批量清理落库失败时返回空数组、保留内存列表，
    /// 绝不报告虚假的「已清理 N 条」。工具管理器替身在清理阶段
    /// （落库删除之前）绕过管理器删掉库行，确定性地构造「查询命中、
    /// 删除返回 false」——save 失败与行被并发删除走同一条 false 分支。
    @Test func bulkDeletionReturnsEmptyAndKeepsMemoryWhenPersistFails() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationBulkDeleteFailure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let now = Date()
        let old = UUID()
        try await store.createConversation(
            id: old, title: "old", createdAt: now.addingTimeInterval(-86_400 * 10)
        )
        let toolManager = RowDeletingToolManager(store: store)
        let manager = ConversationManager(
            store: store, dataDirectory: directory, toolManager: toolManager
        )
        manager.conversations = [ConversationSummary(id: old, title: "old")]

        let deleted = await manager.deleteConversations(
            createdBefore: now.addingTimeInterval(-86_400),
            projectPath: nil,
            includingChildConversations: false
        )

        // 落库失败：不报告任何已删除 ID，内存列表原样保留。
        #expect(deleted.isEmpty)
        #expect(manager.conversations.map(\.id) == [old])
    }

    /// 回归 #535：删除进行中的「复活窗口」里，数据库行仍在，但分页重载必须靠
    /// 墓碑排除该 ID，选中入口也必须拒绝它。直接构造该窗口（标记墓碑但不真删），
    /// 确定性地证明排除来自墓碑而非数据库已空。
    @Test func deletionTombstoneExcludesConversationFromReloadAndSelection() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationTombstoneWindow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)
        let doomed = try await manager.createConversationAndWait(
            title: "Doomed", projectPath: nil, modelID: nil, parentConversationID: nil
        )
        let survivor = try await manager.createConversationAndWait(
            title: "Survivor", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        // 构造「删除进行中」窗口：数据库行仍在，墓碑已标记。
        manager.pendingDeletionIDs = [doomed]

        // 列表刷新走的分页读取必须排除墓碑 ID，不能把它复活；存活会话不受影响。
        let page = try await manager.loadConversationPage(limit: 40, includingChildConversations: false)
        #expect(!page.contains { $0.id == doomed })
        #expect(page.contains { $0.id == survivor })

        // 选中入口必须拒绝墓碑 ID，不把幽灵 ID 写回选中态。
        manager.selectConversation(id: survivor)
        #expect(manager.selectedConversationID == survivor)
        manager.selectConversation(id: doomed)
        #expect(manager.selectedConversationID == survivor)

        // 解除墓碑后数据库行重新可见：证明上面的排除来自墓碑，而不是行已被删。
        manager.pendingDeletionIDs = []
        let restored = try await manager.loadConversationPage(limit: 40, includingChildConversations: false)
        #expect(restored.contains { $0.id == doomed })
    }

    /// 回归 #535：`deleteConversation` 必须在广播 `.deleted` 之前同步标记墓碑，
    /// 删除窗口内点选幽灵 ID 被拒绝；后台清理完成后墓碑解除、数据库行消失。
    @Test func deleteConversationMarksTombstoneSynchronouslyAndClearsAfterCleanup() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationTombstoneLifecycle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let manager = ConversationManager(store: store, dataDirectory: directory)
        let id = try await manager.createConversationAndWait(
            title: "Doomed", projectPath: nil, modelID: nil, parentConversationID: nil
        )
        #expect(manager.selectedConversationID == id)

        manager.deleteConversation(id: id)
        // 同步窗口（后台 Task 尚未运行）：墓碑立即生效，乐观移除立即生效。
        #expect(manager.pendingDeletionIDs.contains(id))
        #expect(!manager.conversations.contains { $0.id == id })
        // 删除窗口内点选幽灵 ID 必须被拒绝，不写回选中态。
        manager.selectConversation(id: id)
        #expect(manager.selectedConversationID != id)

        // 等后台清理完成：数据库行消失，墓碑解除。
        var remaining = await store.fetchConversation(id: id)
        for _ in 0..<100 where remaining != nil {
            try await Task.sleep(for: .milliseconds(20))
            remaining = await store.fetchConversation(id: id)
        }
        #expect(remaining == nil)
        #expect(!manager.pendingDeletionIDs.contains(id))
    }

    /// 回归 #535：用门闩把异步清理挡在 `deleteToolCalls`，构造「慢清理」。
    /// 清理未完成期间墓碑必须持续生效（重载仍排除该 ID），放行后才解除。
    /// 只测最终成功路径不算覆盖异步写回约定（仓库约定）。
    @Test func slowCleanupHoldsTombstoneUntilCleanupFinishes() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationTombstoneSlowCleanup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try ConversationStore(databaseRootURL: directory)
        let gate = CleanupGate()
        let manager = ConversationManager(
            store: store, dataDirectory: directory, toolManager: GatedToolManager(gate: gate)
        )
        let id = try await manager.createConversationAndWait(
            title: "Doomed", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        manager.deleteConversation(id: id)
        #expect(manager.pendingDeletionIDs.contains(id))

        // 等清理推进到 deleteToolCalls 并被门闩挡住：此时清理尚未完成。
        await gate.waitUntilReached()
        #expect(manager.pendingDeletionIDs.contains(id))
        let page = try await manager.loadConversationPage(limit: 40, includingChildConversations: false)
        #expect(!page.contains { $0.id == id })

        // 放行清理，等墓碑解除。
        gate.release()
        for _ in 0..<100 where manager.pendingDeletionIDs.contains(id) {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(!manager.pendingDeletionIDs.contains(id))
    }
}

/// #801 批量删除失败回归替身：在清理阶段的 `deleteToolCalls`（落库删除之前）
/// 绕过管理器删掉库行，让随后的 `store.deleteConversations` fetch 不到模型而返回 false。
@MainActor
private final class RowDeletingToolManager: ToolManagerProviding {
    private let store: ConversationStore
    init(store: ConversationStore) { self.store = store }

    func deleteToolCalls(for conversationID: UUID) async {
        _ = await store.deleteConversations(ids: [conversationID])
    }

    func allTools() -> [any SuperAgentTool] { [] }
    func add(_ tool: any SuperAgentTool, pluginID: String) {}
    func remove(id: String) {}
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
    func tool(named name: String) -> (any SuperAgentTool)? { nil }
    func displayDescription(for toolCall: ToolCall) -> String? { nil }
    func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? { nil }
    func execute(_ toolCall: ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult {
        ToolCallResult(content: "", isError: false)
    }
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
}

/// #535 慢清理门闩：让测试确定性地停在异步清理中途，验证墓碑的生命周期。
@MainActor
private final class CleanupGate {
    private var reachedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var reached = false
    private var released = false

    /// 清理替身进入 `deleteToolCalls` 时调用，唤醒等待中的测试。
    func signalReached() {
        reached = true
        reachedContinuation?.resume()
        reachedContinuation = nil
    }

    func waitUntilReached() async {
        if reached { return }
        await withCheckedContinuation { reachedContinuation = $0 }
    }

    /// 测试放行清理。
    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func waitUntilReleased() async {
        if released { return }
        await withCheckedContinuation { releaseContinuation = $0 }
    }
}

/// #535 慢清理替身：在 `deleteToolCalls` 处被门闩挡住，模拟「清理很慢」。
@MainActor
private final class GatedToolManager: ToolManagerProviding {
    private let gate: CleanupGate
    init(gate: CleanupGate) { self.gate = gate }

    func deleteToolCalls(for conversationID: UUID) async {
        gate.signalReached()
        await gate.waitUntilReleased()
    }

    func allTools() -> [any SuperAgentTool] { [] }
    func add(_ tool: any SuperAgentTool, pluginID: String) {}
    func remove(id: String) {}
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
    func tool(named name: String) -> (any SuperAgentTool)? { nil }
    func displayDescription(for toolCall: ToolCall) -> String? { nil }
    func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? { nil }
    func execute(_ toolCall: ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult {
        ToolCallResult(content: "", isError: false)
    }
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
}
