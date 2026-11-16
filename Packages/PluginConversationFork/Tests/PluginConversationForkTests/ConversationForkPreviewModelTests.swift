import Foundation
import Testing
import ProviderConversation
import ProviderMessage
import ProviderLLMManager
import ProviderMessageSender
import ProviderAgentLoop
import ProviderLifecycleHooks

@testable import PluginConversationFork

/// #463 回归：分叉弹窗预览的异步加载必须带身份校验。
///
/// 用门闩快照替身构造「旧请求晚到」：先打开 A 的预览，再打开 B，
/// 然后按不同顺序放行两次快照，断言只有最新一次打开的结果能发布。
@Suite("ConversationForkPreviewModel")
@MainActor
struct ConversationForkPreviewModelTests {
    private func makeModel(
        conversations: DefaultConversationManager,
        messages: GatedSnapshotMessageManager
    ) -> ConversationForkPreviewModel {
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: NoopAgentLoop()
        )
        let summarizer = ConversationSummarizer(
            conversations: conversations,
            messages: messages,
            llmProvider: DefaultLLMProviderManagerProviding()
        )
        let coordinator = ConversationForkCoordinator(
            conversations: conversations,
            messages: messages,
            sender: sender,
            summarizer: summarizer
        )
        return ConversationForkPreviewModel(coordinator: coordinator)
    }

    /// 建两个各带一条提问的对话，返回 (A, B)。
    private func makeTwoConversations(
        _ conversations: DefaultConversationManager,
        messages: GatedSnapshotMessageManager
    ) throws -> (UUID, UUID) {
        let a = try conversations.createConversation(title: "对话A", projectPath: nil, providerID: nil, modelName: nil)
        let b = try conversations.createConversation(title: "对话B", projectPath: nil, providerID: nil, modelName: nil)
        messages.insertMessage(Message(conversationID: a, role: .user, content: "问题A"), to: a)
        messages.insertMessage(Message(conversationID: b, role: .user, content: "问题B"), to: b)
        return (a, b)
    }

    /// 等待条件成立；让出主线程给在途 Task（含 detached 过滤 hop）。
    private func waitUntil(
        _ condition: @MainActor () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        for i in 0..<2_000 {
            if condition() { return }
            await Task.yield()
            if i % 100 == 99 { try? await Task.sleep(nanoseconds: 1_000_000) }
        }
        Issue.record("等待条件超时", sourceLocation: sourceLocation)
    }

    /// 给被丢弃的旧请求留出「晚到并试图写回」的时间窗口。
    private func settle() async {
        for _ in 0..<50 { await Task.yield() }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }

    @Test("旧预览在新加载进行中晚到：不发布也不关掉加载标记")
    func stalePreviewDuringNewLoadIsDiscarded() async throws {
        let conversations = DefaultConversationManager()
        let messages = GatedSnapshotMessageManager()
        let (a, b) = try makeTwoConversations(conversations, messages: messages)
        let model = makeModel(conversations: conversations, messages: messages)

        model.open(for: a)
        await waitUntil { messages.snapshotRequests.contains(a) }
        model.open(for: b)
        await waitUntil { messages.snapshotRequests.contains(b) }

        // 旧请求（A）先回来：此时 B 仍在加载，A 的结果必须整体丢弃。
        messages.releaseSnapshot(for: a)
        await settle()
        #expect(model.preview == nil)
        #expect(model.isLoading)
        #expect(model.target == b)

        messages.releaseSnapshot(for: b)
        await waitUntil { model.preview != nil }
        #expect(model.preview?.title == "对话B")
        #expect(model.preview?.lastRequest == "问题B")
        #expect(!model.isLoading)
    }

    @Test("旧预览在新加载完成后晚到：不覆盖已发布的新预览")
    func stalePreviewAfterNewLoadIsDiscarded() async throws {
        let conversations = DefaultConversationManager()
        let messages = GatedSnapshotMessageManager()
        let (a, b) = try makeTwoConversations(conversations, messages: messages)
        let model = makeModel(conversations: conversations, messages: messages)

        model.open(for: a)
        await waitUntil { messages.snapshotRequests.contains(a) }
        model.open(for: b)
        await waitUntil { messages.snapshotRequests.contains(b) }

        messages.releaseSnapshot(for: b)
        await waitUntil { model.preview != nil }
        #expect(model.preview?.title == "对话B")

        // A 的结果最后才到：不得把弹窗内容盖回 A（确认按钮分叉的是 B）。
        messages.releaseSnapshot(for: a)
        await settle()
        #expect(model.preview?.title == "对话B")
        #expect(model.preview?.lastRequest == "问题B")
        #expect(!model.isLoading)
        #expect(model.target == b)
    }

    @Test("同一对话重复打开：只认最新一次请求")
    func reopenSameConversationDiscardsEarlierRequest() async throws {
        let conversations = DefaultConversationManager()
        let messages = GatedSnapshotMessageManager()
        let (a, _) = try makeTwoConversations(conversations, messages: messages)
        let model = makeModel(conversations: conversations, messages: messages)

        model.open(for: a)
        await waitUntil { messages.snapshotRequests.count == 1 }
        model.open(for: a)
        await waitUntil { messages.snapshotRequests.count == 2 }

        // 第一次（旧代次）快照先回来：必须丢弃，且不能关掉第二次的加载标记。
        messages.releaseSnapshot(for: a)
        await settle()
        #expect(model.preview == nil)
        #expect(model.isLoading)

        messages.releaseSnapshot(for: a)
        await waitUntil { model.preview != nil }
        #expect(model.preview?.title == "对话A")
        #expect(!model.isLoading)
    }

    @Test("无选中对话时清空状态，晚到的旧结果也不得发布")
    func openWithoutSelectionClearsStateAndIgnoresLateResult() async throws {
        let conversations = DefaultConversationManager()
        let messages = GatedSnapshotMessageManager()
        let (a, _) = try makeTwoConversations(conversations, messages: messages)
        let model = makeModel(conversations: conversations, messages: messages)

        model.open(for: a)
        await waitUntil { messages.snapshotRequests.contains(a) }
        model.open(for: nil)
        #expect(model.preview == nil)
        #expect(!model.isLoading)
        #expect(model.target == nil)

        messages.releaseSnapshot(for: a)
        await settle()
        #expect(model.preview == nil)
        #expect(!model.isLoading)
        #expect(model.target == nil)
    }

    @Test("单次打开正常发布预览并锁定目标对话")
    func singleOpenPublishesPreview() async throws {
        let conversations = DefaultConversationManager()
        let messages = GatedSnapshotMessageManager()
        let (a, _) = try makeTwoConversations(conversations, messages: messages)
        let model = makeModel(conversations: conversations, messages: messages)

        model.open(for: a)
        #expect(model.isLoading)
        #expect(model.target == a)
        await waitUntil { messages.snapshotRequests.contains(a) }
        messages.releaseSnapshot(for: a)
        await waitUntil { model.preview != nil }

        #expect(model.preview?.title == "对话A")
        #expect(model.preview?.lastRequest == "问题A")
        #expect(model.preview?.messageCount == 1)
        #expect(model.preview?.requestCount == 1)
        #expect(!model.isLoading)
    }
}

// MARK: - 门闩快照替身

/// 快照读取被门闩挂起的消息管理器：测试可以按对话、按先进先出顺序
/// 放行快照，从而精确构造「旧请求晚到」的时序。其余能力委托默认实现。
@MainActor
private final class GatedSnapshotMessageManager: MessageManaging {
    private let base = DefaultMessageManager()
    private var gates: [UUID: [CheckedContinuation<Void, Never>]] = [:]
    private(set) var snapshotRequests: [UUID] = []

    func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        snapshotRequests.append(conversationID)
        await withCheckedContinuation { continuation in
            gates[conversationID, default: []].append(continuation)
        }
        return base.messages(for: conversationID)
    }

    /// 放行指定对话最早挂起的一次快照。
    func releaseSnapshot(for conversationID: UUID) {
        guard var queue = gates[conversationID], !queue.isEmpty else { return }
        let continuation = queue.removeFirst()
        gates[conversationID] = queue
        continuation.resume()
    }

    func messages(for conversationID: UUID) -> [Message] { base.messages(for: conversationID) }
    func message(id: UUID, in conversationID: UUID) -> Message? { base.message(id: id, in: conversationID) }
    func lastMessage(in conversationID: UUID) -> Message? { base.lastMessage(in: conversationID) }
    func messageCount(for conversationID: UUID) -> Int { base.messageCount(for: conversationID) }
    func insertMessage(_ message: Message, to conversationID: UUID) { base.insertMessage(message, to: conversationID) }
    func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        base.updateMessage(id: id, in: conversationID, content: content)
    }
    func deleteMessage(id: UUID, in conversationID: UUID) { base.deleteMessage(id: id, in: conversationID) }
    func clearMessages(in conversationID: UUID) { base.clearMessages(in: conversationID) }
    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String?
    ) {
        base.updateToolCallResult(
            result,
            toolCallID: toolCallID,
            assistantMessageID: assistantMessageID,
            in: conversationID,
            authorizationState: authorizationState
        )
    }
}

// MARK: - 空回合替身

/// 预览链路不启动回合；sender 只需要一个能构造出来的 AgentLoop。
private final class NoopAgentLoop: AgentLoopProviding {
    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        NoopAgentLoopObserverHandle()
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        throw AgentLoopError.invalidResumeRequest
    }
    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class NoopAgentLoopObserverHandle: AgentLoopObserverHandle {
    func cancel() {}
}