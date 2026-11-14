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

        func updateToolCallResult(
            _ result: MessageToolResult,
            toolCallID: String,
            assistantMessageID: UUID,
            in conversationID: UUID
        ) {
            guard var history = stored[conversationID],
                  let index = history.firstIndex(where: { $0.id == assistantMessageID }),
                  var toolCalls = history[index].toolCalls,
                  let callIndex = toolCalls.firstIndex(where: { $0.id == toolCallID }) else { return }
            toolCalls[callIndex].result = result
            history[index].toolCalls = toolCalls
            stored[conversationID] = history
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

    /// 回归 #805：挂起回合被回答后重新执行，同一 turnID 会再次触发
    /// turnStarted。此刻崩溃，记录必须停在「运行中」而不是 `.suspended`，
    /// 否则重启后 ResumeEligibility 拒绝恢复，「继续」提示不出现。
    @Test("挂起回合恢复执行后崩溃，仍显示继续提示")
    func resumedSuspendedTurnCrashStillShowsBanner() async {
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

        // 回合开始 → ask_user 挂起：记录为 .suspended，不可继续。
        await hooks.notifyTurnStarted(
            TurnLifecycleContext(conversationID: conversationID, turnID: turnID)
        )
        await hooks.notifyTurnFinished(
            TurnLifecycleContext(
                conversationID: conversationID,
                turnID: turnID,
                endReason: .suspended
            )
        )
        await coordinator.refreshState(for: conversationID)
        #expect(coordinator.state.isResumable == false)

        // 用户回答后同一回合恢复执行（再次 turnStarted），随后崩溃——
        // 没有终态事件。
        await hooks.notifyTurnStarted(
            TurnLifecycleContext(conversationID: conversationID, turnID: turnID)
        )
        let record = await store.record(for: conversationID)
        #expect(record?.outcome == .interrupted)
        #expect(record?.turnID == turnID)

        // 重启后（AgentLoop 回到 idle）应当提示「继续」。
        loop.state = .idle
        await coordinator.refreshState(for: conversationID)
        #expect(coordinator.state.isResumable == true)
        coordinator.cancel()
    }

    /// 回归 #854：挂起期间退出 app（未回答），重启后「继续」必须出现。
    /// 挂起运行时随进程消失，磁盘上的 `.suspended` 记录在新进程里
    /// 只能按中断处理。
    @Test("挂起期间退出 app，重启后显示继续提示")
    func quitDuringSuspensionShowsBannerAfterRestart() async {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let conversationID = UUID()
        let turnID = UUID()
        let messages = FakeMessages()
        let conversations = FakeConversations()
        conversations.selectedConversationID = conversationID
        messages.seed([
            userMessage(conversationID),
            assistantWithToolCall(conversationID, turnID: turnID),
        ], for: conversationID)

        // 第一个进程：回合开始 → ask_user 挂起，记录落盘为 .suspended。
        let hooks = makeHooks()
        let firstCoordinator = makeCoordinator(
            loop: FakeAgentLoop(),
            messages: messages,
            conversations: conversations,
            store: store
        )
        firstCoordinator.start(hooks: makeHooksCapability(hooks))
        await hooks.notifyTurnStarted(
            TurnLifecycleContext(conversationID: conversationID, turnID: turnID)
        )
        await hooks.notifyTurnFinished(
            TurnLifecycleContext(
                conversationID: conversationID,
                turnID: turnID,
                endReason: .suspended
            )
        )
        await firstCoordinator.refreshState(for: conversationID)
        #expect(firstCoordinator.state.isResumable == false, "活挂起仍可交互，不该提示继续")
        firstCoordinator.cancel()

        // 用户未回答就退出 app。重启：新 store 读同一文件，AgentLoop 回到 idle。
        let restartedStore = ResumableTurnStore(fileURL: url)
        let restartedCoordinator = makeCoordinator(
            loop: FakeAgentLoop(),
            messages: messages,
            conversations: conversations,
            store: restartedStore
        )
        restartedCoordinator.start(hooks: makeHooksCapability(makeHooks()))
        await restartedCoordinator.refreshState(for: conversationID)

        #expect(restartedCoordinator.state.isResumable == true)
        restartedCoordinator.cancel()
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

    /// 回归 #634：修复不能只插独立 `.tool` 消息，还要回写 assistant 内
    /// 嵌套的 toolCall.result。否则渲染层读到 result == nil，工具行与
    /// 折叠组永久 loading。
    @Test("修复后 assistant 嵌套工具结果被回写，不再永久 loading")
    func resumeWritesNestedToolCallResult() async {
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
        let assistant = history.first { $0.role == .assistant }
        let nested = assistant?.toolCalls?.first?.result
        #expect(nested != nil, "嵌套结果必须回写，否则 UI 永久 loading")
        #expect(nested?.content == OrphanToolCallRepair.placeholderContent)
        #expect(nested?.isError == true)
        coordinator.cancel()
    }

    /// 回归 #633：崩溃发生在「嵌套真实结果已落库、独立 tool 消息未插入」
    /// 之间时，继续必须用真实结果重建协议消息，且不得用占位覆盖快照。
    @Test("嵌套真实结果被重建为独立 tool 消息，快照不被占位覆盖")
    func resumeRebuildsRealResultAndKeepsSnapshot() async {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let conversationID = UUID()
        let turnID = UUID()
        let loop = FakeAgentLoop()
        let messages = FakeMessages()
        let conversations = FakeConversations()
        conversations.selectedConversationID = conversationID
        var call = MessageToolCall(id: "call_1", name: "read_file", arguments: "{}")
        call.result = MessageToolResult(content: "done")
        let assistant = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            turnID: turnID,
            toolCalls: [call]
        )
        messages.seed([userMessage(conversationID), assistant], for: conversationID)
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
        let toolMessages = history.filter { $0.role == .tool }
        #expect(toolMessages.count == 1)
        #expect(toolMessages[0].toolCallID == "call_1")
        #expect(toolMessages[0].content == "done", "真实结果不得被占位替换")
        #expect(toolMessages[0].isError == false)

        let nested = history.first { $0.id == assistant.id }?.toolCalls?.first?.result
        #expect(nested?.content == "done", "已有真实结果的快照不得被占位覆盖")
        #expect(OrphanToolCallScanner.scan(history).isEmpty)
        #expect(loop.startTurnCount == 1)
        coordinator.cancel()
    }

    /// 回归 #635：旧回合的终态钩子被串行 await，可能在新回合已经开始
    /// （markRunning 落盘）之后才到达。迟到的旧终态不得把新回合的中断
    /// 记录抹掉，否则崩溃重启后「继续」提示不出现。
    @Test("旧回合迟到终态不覆盖新回合记录，继续提示仍在")
    func staleTerminalHookDoesNotHideResumeBanner() async {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let conversationID = UUID()
        let turn1 = UUID()
        let turn2 = UUID()
        let loop = FakeAgentLoop()
        let messages = FakeMessages()
        let conversations = FakeConversations()
        conversations.selectedConversationID = conversationID
        messages.seed([
            userMessage(conversationID),
            assistantWithToolCall(conversationID, turnID: turn2),
        ], for: conversationID)
        let hooks = makeHooks()
        let coordinator = makeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        )
        coordinator.start(hooks: makeHooksCapability(hooks))

        // 新回合先开始，旧回合的终态随后才迟到。
        await hooks.notifyTurnStarted(
            TurnLifecycleContext(conversationID: conversationID, turnID: turn1)
        )
        await hooks.notifyTurnStarted(
            TurnLifecycleContext(conversationID: conversationID, turnID: turn2)
        )
        await hooks.notifyTurnFinished(
            TurnLifecycleContext(
                conversationID: conversationID,
                turnID: turn1,
                endReason: .completed
            )
        )
        await coordinator.refreshState(for: conversationID)

        let record = await store.record(for: conversationID)
        #expect(record?.turnID == turn2)
        #expect(record?.outcome == .interrupted)
        #expect(coordinator.state.isResumable == true)

        // 当前回合自己的终态仍然正常生效。
        await hooks.notifyTurnFinished(
            TurnLifecycleContext(
                conversationID: conversationID,
                turnID: turn2,
                endReason: .completed
            )
        )
        await coordinator.refreshState(for: conversationID)
        #expect(coordinator.state.isResumable == false)
        coordinator.cancel()
    }

    /// 回归 #636：孤儿调用之后已存在新用户消息（ACP 先插消息再排回合，
    /// 崩溃可留下该状态）时，占位必须插在 assistant 与该用户消息之间，
    /// 而不是按当前时间追加到历史末尾——否则 Anthropic 顺序非法。
    @Test("孤儿调用后已有用户消息时，占位插在该用户消息之前")
    func resumeInsertsPlaceholderBeforeLaterUserMessage() async {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let conversationID = UUID()
        let turnID = UUID()
        let loop = FakeAgentLoop()
        let messages = FakeMessages()
        let conversations = FakeConversations()
        conversations.selectedConversationID = conversationID
        let user1 = Message(
            conversationID: conversationID, role: .user, content: "U1",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let assistant = Message(
            conversationID: conversationID, role: .assistant, content: "",
            createdAt: Date(timeIntervalSince1970: 2_000),
            turnID: turnID,
            toolCalls: [MessageToolCall(id: "call_1", name: "read_file", arguments: "{}")]
        )
        let user2 = Message(
            conversationID: conversationID, role: .user, content: "continue",
            createdAt: Date(timeIntervalSince1970: 3_000)
        )
        messages.seed([user1, assistant, user2], for: conversationID)
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

        // 真实 MessageManager 按 createdAt 排序快照，这里同样排序后断言。
        let history = (await messages.messages(for: conversationID))
            .sorted { $0.createdAt < $1.createdAt }
        #expect(history.map(\.role) == [.user, .assistant, .tool, .user])
        #expect(history[2].toolCallID == "call_1")
        #expect(history[3].id == user2.id)
        #expect(loop.startTurnCount == 1)
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
