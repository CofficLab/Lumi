import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginConversationSpeed

/// 「旧选择快照覆盖新插入统计」的回归测试（#1156）。
///
/// 选择会话与消息插入各自排程异步快照，两条写回链路此前没有顺序保证：
/// 选择快照 S0 先捕获（空数组）、后返回，就能把插入快照 S1 刚写好的
/// TPS / 历史 / 请求数整个抹掉，且不需要任何后续事件就会一直停在旧状态。
///
/// 修复：ViewModel 维护刷新代次，每次选择 / 插入事件同步递增；
/// 异步快照排程时记录代次，写回前比对，期间出现过更新事件即丢弃。

/// 首帧快照可被门闩挂起的 `MessageManaging` 包装。
///
/// 第一次 `messagesSnapshot` 捕获当时的消息后 suspends，直到
/// `releaseFirstSnapshot()`；之后的快照直接透传，模拟「旧快照晚到」。
@MainActor
private final class GatedSnapshotMessageManager: MessageManaging {
    private let inner = DefaultMessageManager()
    var gateFirstSnapshot = false
    private(set) var firstSnapshotCaptured = false
    private var gateContinuation: CheckedContinuation<Void, Never>?

    func releaseFirstSnapshot() {
        gateContinuation?.resume()
        gateContinuation = nil
    }

    func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        if gateFirstSnapshot, !firstSnapshotCaptured {
            firstSnapshotCaptured = true
            let captured = inner.messages(for: conversationID)
            await withCheckedContinuation { gateContinuation = $0 }
            return captured
        }
        return await inner.messagesSnapshot(in: conversationID)
    }

    func messages(for conversationID: UUID) -> [Message] { inner.messages(for: conversationID) }
    func message(id: UUID, in conversationID: UUID) -> Message? { inner.message(id: id, in: conversationID) }
    func lastMessage(in conversationID: UUID) -> Message? { inner.lastMessage(in: conversationID) }
    func messageCount(for conversationID: UUID) -> Int { inner.messageCount(for: conversationID) }
    func insertMessage(_ message: Message, to conversationID: UUID) { inner.insertMessage(message, to: conversationID) }
    func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        inner.updateMessage(id: id, in: conversationID, content: content)
    }
    func deleteMessage(id: UUID, in conversationID: UUID) { inner.deleteMessage(id: id, in: conversationID) }
    func clearMessages(in conversationID: UUID) { inner.clearMessages(in: conversationID) }
    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String?
    ) {
        inner.updateToolCallResult(
            result,
            toolCallID: toolCallID,
            assistantMessageID: assistantMessageID,
            in: conversationID,
            authorizationState: authorizationState
        )
    }
    func addMessageInsertedObserver(
        _ callback: @escaping (Message, UUID) -> Void
    ) -> any MessageInsertedObserverHandle {
        inner.addMessageInsertedObserver(callback)
    }
}

@Test @MainActor func staleSelectionSnapshotMustNotOverwriteNewerInsertionStats() async throws {
    let conversations = DefaultConversationManager()
    let messages = GatedSnapshotMessageManager()

    let viewModel = ConversationSpeedViewModel()
    viewModel.setPopoverPresented(true)
    messages.gateFirstSnapshot = true
    let selectionObserver = SpeedConversationObserver(
        conversations: conversations, messages: messages, viewModel: viewModel
    )
    let messageObserver = SpeedMessageObserver(messages: messages, viewModel: viewModel)

    // 创建会话会自动选中：观察者同步绑定 A，选择快照 S0 捕获 [] 并被门闩挂起。
    let id = try conversations.createConversation(title: "A", projectPath: nil, providerID: nil, modelName: nil)
    let captured = await waitUntil { messages.firstSnapshotCaptured }
    #expect(captured)
    #expect(viewModel.selectedConversationID == id)

    // 插入一条 assistant 响应：120 tokens / 6000ms → TPS 20。
    // 插入观察者的快照 S1 不受门闩影响，先行返回并写回。
    messages.insertMessage(
        speedStaleSnapshotMessage(conversationID: id, outputTokens: 120, durationMs: 6_000),
        to: id
    )
    let freshLanded = await waitUntil { viewModel.cachedTPS == 20 }
    #expect(freshLanded)
    #expect(viewModel.requestCount == 1)
    #expect(viewModel.speedHistory.count == 1)

    // 释放过时的 S0，此后不再发出任何选择 / 插入事件。
    messages.releaseFirstSnapshot()
    let clobbered = await waitUntil(timeout: .milliseconds(300)) { viewModel.cachedTPS != 20 }
    #expect(!clobbered, "旧选择快照覆盖了新插入的统计（TPS 被抹掉）")
    #expect(viewModel.requestCount == 1)
    #expect(viewModel.speedHistory.count == 1)

    // 丢弃旧快照后管道必须仍然可用：后续插入照常刷新。
    messages.insertMessage(
        speedStaleSnapshotMessage(conversationID: id, outputTokens: 60, durationMs: 3_000),
        to: id
    )
    let followUpLanded = await waitUntil { viewModel.requestCount == 2 }
    #expect(followUpLanded)

    selectionObserver.cancel()
    messageObserver.cancel()
}

/// 插入-vs-插入的过时快照回归（#539）：同一会话连续插入 M1、M2，
/// M1 的刷新越过 150ms 去抖后阻塞在快照 S1（只含 M1）；M2 取消 S1 的外层任务，
/// S2 先返回 [M1, M2] 写回；随后释放的 S1 不得把统计抹回 M1。
/// 锁定 SpeedMessageObserver 在 `messagesSnapshot` await 之后的取消/代次再校验。
@Test @MainActor func staleInsertionSnapshotMustNotOverwriteNewerInsertionStats() async throws {
    let conversations = DefaultConversationManager()
    let messages = GatedSnapshotMessageManager()

    let viewModel = ConversationSpeedViewModel()
    viewModel.setPopoverPresented(true)
    let id = try conversations.createConversation(title: "A", projectPath: nil, providerID: nil, modelName: nil)
    viewModel.selectConversation(id, messages: [])

    // 门闩挂起消息观察者的第一条快照 S1（只含 M1）。
    messages.gateFirstSnapshot = true
    let messageObserver = SpeedMessageObserver(messages: messages, viewModel: viewModel)

    // 插入 M1：120 tokens / 6000ms → TPS 20。刷新越过 150ms 去抖后阻塞在 S1。
    messages.insertMessage(
        speedStaleSnapshotMessage(conversationID: id, outputTokens: 120, durationMs: 6_000),
        to: id
    )
    let captured = await waitUntil { messages.firstSnapshotCaptured }
    #expect(captured)

    // 插入 M2：300 tokens / 3000ms → TPS 100。取消 S1 的外层任务，
    // S2 不受门闩影响先返回 [M1, M2] 并写回。
    messages.insertMessage(
        speedStaleSnapshotMessage(conversationID: id, outputTokens: 300, durationMs: 3_000),
        to: id
    )
    let freshLanded = await waitUntil { viewModel.cachedTPS == 100 }
    #expect(freshLanded)
    #expect(viewModel.requestCount == 2)

    // 释放过时的 S1（只含 M1）：写回前的取消/代次校验必须丢弃它。
    messages.releaseFirstSnapshot()
    let clobbered = await waitUntil(timeout: .milliseconds(300)) { viewModel.cachedTPS != 100 }
    #expect(!clobbered, "旧插入快照覆盖了新插入的统计（TPS 被抹回 M1）")
    #expect(viewModel.requestCount == 2)
    #expect(viewModel.cachedTPS == 100)

    // 丢弃旧快照后管道仍可用：后续插入照常刷新。
    messages.insertMessage(
        speedStaleSnapshotMessage(conversationID: id, outputTokens: 90, durationMs: 3_000),
        to: id
    )
    let followUpLanded = await waitUntil { viewModel.requestCount == 3 }
    #expect(followUpLanded)

    messageObserver.cancel()
}

@Test @MainActor func gatedSelectionSnapshotStillCommitsWhenNoNewerEvent() async throws {
    let conversations = DefaultConversationManager()
    let messages = GatedSnapshotMessageManager()
    let id = try conversations.createConversation(title: "A", projectPath: nil, providerID: nil, modelName: nil)
    messages.insertMessage(
        speedStaleSnapshotMessage(conversationID: id, outputTokens: 80, durationMs: 4_000),
        to: id
    )
    conversations.selectConversation(id: id)

    let viewModel = ConversationSpeedViewModel()
    messages.gateFirstSnapshot = true
    let observer = SpeedConversationObserver(
        conversations: conversations, messages: messages, viewModel: viewModel
    )
    let captured = await waitUntil { messages.firstSnapshotCaptured }
    #expect(captured)
    #expect(viewModel.cachedTPS == nil)

    // 没有更新事件时，挂起的快照释放后必须正常写回，不能被代次检查误杀。
    messages.releaseFirstSnapshot()
    let landed = await waitUntil { viewModel.cachedTPS == 20 }
    #expect(landed)
    #expect(viewModel.requestCount == 1)
    observer.cancel()
}

private func speedStaleSnapshotMessage(conversationID: UUID, outputTokens: Int, durationMs: Double) -> Message {
    Message(
        conversationID: conversationID,
        role: .assistant,
        content: "response",
        outputTokenCount: outputTokens,
        streamingDurationMs: durationMs
    )
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(2),
    condition: @MainActor () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}