import Foundation
import ProviderLifecycleHooks
import ProviderMessage
import Testing
@testable import PluginConversationResume

/// 协调器的端到端行为测试。
///
/// 覆盖完整链路：回合开始 → 崩溃（无终态事件）→ 判定可继续 → 点击继续
/// → 修复孤儿 tool_call → 启动新回合。
@MainActor
struct ResumeCoordinatorTests {
    // MARK: - 测试替身

    /// 记录调用并可控制回合状态的 AgentLoop 替身。
    final class FakeAgentLoop: ResumeAgentLoopCapability {
        var state: ResumeEligibility.AgentLoopStateSnapshot = .idle
        var startTurnCount = 0
        var startedConversationIDs: [UUID] = []

        func turnState(for conversationID: UUID) -> ResumeEligibility.AgentLoopStateSnapshot {
            state
        }

        func startTurn(for conversationID: UUID) async {
            startTurnCount += 1
            startedConversationIDs.append(conversationID)
            // 真实实现会在回合开始时把状态置为 running。
            state = .running
        }
    }

    /// 内存消息仓库替身。
    final class FakeMessages: ResumeMessageCapability {
        private(set) var stored: [UUID: [Message]] = [:]
        private var observers: [UUID: (UUID) -> Void] = [:]

        /// 预置历史消息（不触发观察回调）。
        func seed(_ messages: [Message], for conversationID: UUID) {
            stored[conversationID] = messages
        }

        func messages(for conversationID: UUID) async -> [Message] {
            stored[conversationID] ?? []
        }

        func insertMessage(_ message: Message, to conversationID: UUID) {
            stored[conversationID, default: []].append(message)
            for observer in observers.values {
                observer(conversationID)
            }
        }

        @discardableResult
        func addObserver(_ callback: @escaping (UUID) -> Void) -> any ResumeMessageObserverHandle {
            let id = UUID()
            observers[id] = callback
            return Handle { [weak self] in
                self?.observers.removeValue(forKey: id)
            }
        }

        final class Handle: ResumeMessageObserverHandle {
            private let cancelAction: () -> Void
            init(cancelAction: @escaping () -> Void) {
                self.cancelAction = cancelAction
            }
            func cancel() { cancelAction() }
        }
    }

    /// 会话选择替身。
    final class FakeConversations: ResumeConversationCapability {
        var selectedConversationID: UUID?
        private var observers: [UUID: (UUID?) -> Void] = [:]

        @discardableResult
        func addObserver(_ callback: @escaping (UUID?) -> Void) -> any ResumeConversationObserverHandle {
            let id = UUID()
            observers[id] = callback
            return Handle { [weak self] in
                self?.observers.removeValue(forKey: id)
            }
        }

        final class Handle: ResumeConversationObserverHandle {
            private let cancelAction: () -> Void
            init(cancelAction: @escaping () -> Void) {
                self.cancelAction = cancelAction
            }
            func cancel() { cancelAction() }
        }
    }

    // MARK: - 辅助

    private func makeStore() -> (store: ResumableTurnStore, url: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-coord-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("turns.json")
        return (ResumableTurnStore(fileURL: url), url)
    }

    private func userMessage(_ conversationID: UUID) -> Message {
        Message(conversationID: conversationID, role: .user, content: "改一下代码")
    }

    private func assistantWithToolCall(
        _ conversationID: UUID,
        turnID: UUID,
        toolCallID: String = "call_1"
    ) -> Message {
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            turnID: turnID,
            toolCalls: [MessageToolCall(id: toolCallID, name: "read_file", arguments: "{}")]
        )
    }

    private func makeCoordinator(
        loop: FakeAgentLoop,
        messages: FakeMessages,
        conversations: FakeConversations,
        store: ResumableTurnStore
    ) -> ResumeCoordinator {
        ResumeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        ) { _ in }
    }

    private func makeHooks() -> DefaultLifecycleHooksProvider {
        DefaultLifecycleHooksProvider()
    }

    /// 收窄后的钩子能力（协调器只认这个）。
    private func makeHooksCapability(
        _ hooks: DefaultLifecycleHooksProvider
    ) -> ResumeLifecycleHooksCapability {
        ResumeLifecycleHooksCapabilityAdapter(hooks: hooks)
    }

    // MARK: - 测试

    @Test("回合正常完成后不显示继续提示")
    func completedTurnShowsNoBanner() async {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let conversationID = UUID()
        let turnID = UUID()
        let loop = FakeAgentLoop()
        let messages = FakeMessages()
        let conversations = FakeConversations()
        conversations.selectedConversationID = conversationID
        messages.seed([
            userMessage(conversationID),
            assistantWithToolCall(conversationID, turnID: turnID),
        ], for: conversationID)
        let hooks = makeHooks()
        let coordinator = makeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        )
        coordinator.start(hooks: makeHooksCapability(hooks))

        await hooks.notifyTurnStarted(
            TurnLifecycleContext(conversationID: conversationID, turnID: turnID)
        )
        await hooks.notifyTurnFinished(
            TurnLifecycleContext(
                conversationID: conversationID,
                turnID: turnID,
                endReason: .completed
            )
        )
        await coordinator.refreshState(for: conversationID)

        #expect(coordinator.state.isResumable == false)
        coordinator.cancel()
    }

    @Test("用户主动停止后不显示继续提示")
    func cancelledTurnShowsNoBanner() async {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let conversationID = UUID()
        let turnID = UUID()
        let loop = FakeAgentLoop()
        let messages = FakeMessages()
        let conversations = FakeConversations()
        conversations.selectedConversationID = conversationID
        messages.seed([
            userMessage(conversationID),
            assistantWithToolCall(conversationID, turnID: turnID),
        ], for: conversationID)
        let hooks = makeHooks()
        let coordinator = makeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        )
        coordinator.start(hooks: makeHooksCapability(hooks))

        await hooks.notifyTurnStarted(
            TurnLifecycleContext(conversationID: conversationID, turnID: turnID)
        )
        await hooks.notifyTurnFinished(
            TurnLifecycleContext(
                conversationID: conversationID,
                turnID: turnID,
                endReason: .cancelled
            )
        )
        await coordinator.refreshState(for: conversationID)

        #expect(coordinator.state.isResumable == false)
        coordinator.cancel()
    }

    @Test("崩溃（无终态事件）后显示继续提示")
    func crashedTurnShowsBanner() async {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let conversationID = UUID()
        let turnID = UUID()
        let loop = FakeAgentLoop()
        let messages = FakeMessages()
        let conversations = FakeConversations()
        conversations.selectedConversationID = conversationID
        messages.seed([
            userMessage(conversationID),
            assistantWithToolCall(conversationID, turnID: turnID),
        ], for: conversationID)
        let hooks = makeHooks()
        let coordinator = makeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        )
        coordinator.start(hooks: makeHooksCapability(hooks))

        // 回合开始，但**没有**终态事件 —— 这就是崩溃。
        await hooks.notifyTurnStarted(
            TurnLifecycleContext(conversationID: conversationID, turnID: turnID)
        )
        await coordinator.refreshState(for: conversationID)

        #expect(coordinator.state.isResumable == true)
        coordinator.cancel()
    }

    @Test("点击继续会补写占位 tool result 并启动新回合")
    func resumeRepairsOrphansAndStartsTurn() async {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let conversationID = UUID()
        let turnID = UUID()
        let loop = FakeAgentLoop()
        let messages = FakeMessages()
        let conversations = FakeConversations()
        conversations.selectedConversationID = conversationID
        messages.seed([
            userMessage(conversationID),
            assistantWithToolCall(conversationID, turnID: turnID),
        ], for: conversationID)
        let hooks = makeHooks()
        let coordinator = makeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        )
        coordinator.start(hooks: makeHooksCapability(hooks))

        await hooks.notifyTurnStarted(
            TurnLifecycleContext(conversationID: conversationID, turnID: turnID)
        )
        await coordinator.refreshState(for: conversationID)
        #expect(coordinator.state.isResumable == true)

        await coordinator.resume()

        // 孤儿 tool_call 被补上占位结果。
        let history = await messages.messages(for: conversationID)
        let toolMessages = history.filter { $0.role == .tool }
        #expect(toolMessages.count == 1)
        #expect(toolMessages[0].toolCallID == "call_1")
        #expect(toolMessages[0].isError)

        // 新回合被启动。
        #expect(loop.startTurnCount == 1)
        #expect(loop.startedConversationIDs == [conversationID])
        coordinator.cancel()
    }

    @Test("恢复后历史不再有孤儿 tool_call")
    func resumeLeavesNoOrphans() async {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let conversationID = UUID()
        let turnID = UUID()
        let loop = FakeAgentLoop()
        let messages = FakeMessages()
        let conversations = FakeConversations()
        conversations.selectedConversationID = conversationID
        messages.seed([
            userMessage(conversationID),
            assistantWithToolCall(conversationID, turnID: turnID),
        ], for: conversationID)
        let hooks = makeHooks()
        let coordinator = makeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        )
        coordinator.start(hooks: makeHooksCapability(hooks))

        await hooks.notifyTurnStarted(
            TurnLifecycleContext(conversationID: conversationID, turnID: turnID)
        )
        await coordinator.resume()

        let history = await messages.messages(for: conversationID)
        #expect(OrphanToolCallScanner.scan(history).isEmpty)
        coordinator.cancel()
    }

    @Test("不可继续时点击继续不会有任何动作")
    func resumeIsNoopWhenNotResumable() async {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let conversationID = UUID()
        let loop = FakeAgentLoop()
        let messages = FakeMessages()
        let conversations = FakeConversations()
        conversations.selectedConversationID = conversationID
        messages.seed([userMessage(conversationID)], for: conversationID)
        let hooks = makeHooks()
        let coordinator = makeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        )
        coordinator.start(hooks: makeHooksCapability(hooks))

        await coordinator.resume()

        #expect(loop.startTurnCount == 0)
        #expect(messages.stored[conversationID]?.filter { $0.role == .tool }.isEmpty == true)
        coordinator.cancel()
    }

    @Test("切换会话后状态按新会话重新判定")
    func switchingConversationRefreshesState() async {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let brokenID = UUID()
        let healthyID = UUID()
        let loop = FakeAgentLoop()
        let messages = FakeMessages()
        let conversations = FakeConversations()
        conversations.selectedConversationID = brokenID
        messages.seed([
            userMessage(brokenID),
            assistantWithToolCall(brokenID, turnID: UUID()),
        ], for: brokenID)
        messages.seed([userMessage(healthyID)], for: healthyID)
        let hooks = makeHooks()
        let coordinator = makeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        )
        coordinator.start(hooks: makeHooksCapability(hooks))

        await store.markRunning(conversationID: brokenID, turnID: UUID())
        await coordinator.refreshState(for: brokenID)
        #expect(coordinator.state.isResumable == true)

        conversations.selectedConversationID = healthyID
        await coordinator.refreshState(for: healthyID)
        #expect(coordinator.state.isResumable == false)
        coordinator.cancel()
    }
}
