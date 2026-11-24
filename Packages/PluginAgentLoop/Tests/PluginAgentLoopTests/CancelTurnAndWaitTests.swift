import Foundation
import KitAgentTool
import KitLLM
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageStreaming
import ProviderLLMContext
import ProviderLLMManager
import ProviderToolManager
import Testing
@testable import PluginAgentLoop

/// `cancelTurnAndWait` 的静默取消语义。
///
/// 同步的 `cancelTurn` 只发出取消信号；编辑并重发要在取消后立刻截断时间线，
/// 必须保证返回之后回合不会再写任何消息。
@MainActor
@Suite("取消并等待回合结束")
struct CancelTurnAndWaitTests {

    @Test("等待 LLM 的回合：Provider 迟到返回之后才返回，且不再写入消息")
    func waitsForLateLLMResponse() async throws {
        let llmManager = LateCancellingLLMManager()
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let loop = makeLoop(messages: messages, llmManager: llmManager)

        let runTask = Task { @MainActor in
            do {
                return try await loop.runTurn(in: conversationID)
            } catch {
                return AgentLoopOutcome.failed(error.localizedDescription)
            }
        }
        try await waitUntil { llmManager.activeRequestCount == 1 }

        var events: [AgentLoopEvent] = []
        let observer = loop.addAgentLoopObserver { events.append($0) }
        defer { observer.cancel() }

        await loop.cancelTurnAndWait(in: conversationID)

        // 返回时迟到的响应已经送达并被丢弃，回合任务已退出。
        #expect(llmManager.activeRequestCount == 0)
        #expect(llmManager.finishedRequestCount == 1)
        #expect(loop.runtimes[conversationID]?.task == nil)
        #expect(!loop.isRunning(for: conversationID))
        #expect(loop.state(for: conversationID) == .cancelled)

        let snapshotAtReturn = messages.messages(for: conversationID)
        try? await Task.sleep(nanoseconds: 150_000_000)
        #expect(messages.messages(for: conversationID).count == snapshotAtReturn.count)
        #expect(messages.messages(for: conversationID).filter { $0.role == .assistant }.isEmpty)
        #expect(await runTask.value == .cancelled)
        #expect(events.contains { if case .cancelled = $0 { true } else { false } })
    }

    @Test("挂起回合：授权占位与协议补全消息都已写完后才返回")
    func suspendedTurnIsSettledBeforeReturning() async throws {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let turnID = UUID()
        let assistantMessageID = UUID()
        let toolCallID = "call_approve_1"
        let loop = makeLoop(messages: messages)
        messages.insertMessage(
            pendingApprovalMessage(
                conversationID: conversationID,
                assistantMessageID: assistantMessageID,
                turnID: turnID,
                toolCallID: toolCallID
            ),
            to: conversationID
        )
        loop.runtimes[conversationID] = TurnRuntime(
            phase: .awaitingUser(
                turnID: turnID,
                assistantMessageID: assistantMessageID,
                pendingToolCalls: [],
                suspension: AgentLoopSuspension(
                    suspensionID: "userInput:\(toolCallID)",
                    conversationID: conversationID,
                    toolCallID: toolCallID,
                    kind: "userInput",
                    payload: "{}"
                )
            ),
            lastTurnID: turnID
        )
        loop.finishTurn(
            conversationID: conversationID,
            turnID: turnID,
            outcome: .suspended("awaiting user response")
        )
        #expect(loop.state(for: conversationID) == .suspended)

        await loop.cancelTurnAndWait(in: conversationID)

        #expect(loop.state(for: conversationID) == .cancelled)
        #expect(loop.suspension(for: conversationID) == nil)
        let assistant = try #require(messages.message(id: assistantMessageID, in: conversationID))
        let toolCall = try #require(assistant.toolCalls?.first { $0.id == toolCallID })
        #expect(toolCall.authorizationState == ToolCallAuthorizationState.userRejected.rawValue)
        #expect(messages.messages(for: conversationID).filter { $0.role == .tool && $0.toolCallID == toolCallID }.count == 1)

        let snapshotAtReturn = messages.messages(for: conversationID).count
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(messages.messages(for: conversationID).count == snapshotAtReturn)
    }

    @Test("空闲会话：立即返回且不发布任何事件")
    func idleConversationReturnsImmediately() async {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let loop = makeLoop(messages: messages)

        var events: [AgentLoopEvent] = []
        let observer = loop.addAgentLoopObserver { events.append($0) }
        defer { observer.cancel() }

        await loop.cancelTurnAndWait(in: conversationID)

        #expect(loop.state(for: conversationID) == .idle)
        #expect(events.isEmpty)
    }

    @Test("重复调用是幂等的")
    func repeatedCallsAreIdempotent() async {
        let llmManager = LateCancellingLLMManager()
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let loop = makeLoop(messages: messages, llmManager: llmManager)
        let runTask = Task { @MainActor in try? await loop.runTurn(in: conversationID) }
        try? await waitUntil { llmManager.activeRequestCount == 1 }

        await loop.cancelTurnAndWait(in: conversationID)
        let countAtFirstReturn = messages.messages(for: conversationID).count
        await loop.cancelTurnAndWait(in: conversationID)

        #expect(messages.messages(for: conversationID).count == countAtFirstReturn)
        #expect(loop.state(for: conversationID) == .cancelled)
        _ = await runTask.value
    }

    @Test("生命周期钩子耗时：返回时 .cancelled 已投递给观察者")
    func deliversCancelledEventBeforeReturningWhenHooksAreSlow() async throws {
        let llmManager = LateCancellingLLMManager()
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let loop = makeLoop(messages: messages, llmManager: llmManager)
        loop.setLifecycleHooks(SlowLifecycleHooks())
        let runTask = Task { @MainActor in try? await loop.runTurn(in: conversationID) }
        try await waitUntil { llmManager.activeRequestCount == 1 }

        var cancelledEventCount = 0
        let observer = loop.addAgentLoopObserver { event in
            if case .cancelled = event { cancelledEventCount += 1 }
        }
        defer { observer.cancel() }

        await loop.cancelTurnAndWait(in: conversationID)

        // 发送器等观察者靠这个事件清掉自己的回合账本；晚于返回到达的话，
        // 紧随其后的提交会被误判为「会话忙」而进入排队。
        #expect(cancelledEventCount == 1)
        _ = await runTask.value
    }

    // MARK: - Support

    private func makeLoop(
        messages: any MessageManaging,
        llmManager: (any LLMManaging)? = nil
    ) -> AgentLoopManager {
        AgentLoopManager(
            messages: messages,
            llmManager: llmManager ?? DefaultLLMManager(),
            toolManager: DefaultToolManagerProviding(),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager(),
            contextProvider: PassthroughLLMContextProvider(messages: messages)
        )
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<200 where !condition() {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        try #require(condition())
    }

    private func pendingApprovalMessage(
        conversationID: UUID,
        assistantMessageID: UUID,
        turnID: UUID,
        toolCallID: String
    ) -> Message {
        Message(
            id: assistantMessageID,
            conversationID: conversationID,
            role: .assistant,
            content: "",
            turnID: turnID,
            toolCalls: [
                MessageToolCall(
                    id: toolCallID,
                    name: "write_file",
                    arguments: #"{"path":"/tmp/a.txt","content":"hi"}"#,
                    result: MessageToolResult(
                        content: #"{"toolCallId":"approval:\#(toolCallID)","kind":"permission","question":"是否允许执行？"}"#,
                        awaitingUserResponse: true,
                        interactionState: .waiting
                    ),
                    authorizationState: ToolCallAuthorizationState.pendingAuthorization.rawValue
                )
            ]
        )
    }
}

/// 取消后不立刻返回、而是稍后才送回迟到响应的 LLM 桩。
///
/// 用来区分「发出取消信号」和「回合任务真正退出」这两个时刻。
private final class LateCancellingLLMManager: LLMManaging, LLMStreamingProviding, @unchecked Sendable {
    private let state = State()

    var activeRequestCount: Int { state.active }
    var finishedRequestCount: Int { state.finished }

    var providerID: String { "late-cancelling-test" }
    var providerInfo: LLMProviderInfo {
        LLMProviderInfo(
            id: providerID,
            displayName: "Late Cancelling Test",
            defaultModel: "test-model",
            models: [LLMModelInfo(id: "test-model")],
            isLocal: true
        )
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        try await streamComplete(request) { _ in }
    }

    func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        try Task.checkCancellation()
        return await withTaskCancellationHandler {
            let response = await withCheckedContinuation { (continuation: CheckedContinuation<LLMResponse, Never>) in
                state.begin(continuation)
            }
            state.end()
            return response
        } onCancel: {
            Task { @Sendable [state] in
                try? await Task.sleep(nanoseconds: 30_000_000)
                state.deliverLateResponse()
            }
        }
    }

    func allProviders() -> [any SuperLLMProvider] { [self] }
    func provider(id: String) -> (any SuperLLMProvider)? { id == providerID ? self : nil }
    var providerCount: Int { 1 }
    func register(_ provider: any SuperLLMProvider) throws {}
    func unregister(id: String) {}
    var selectedProviderID: String? { providerID }
    var selectedModel: String? { "test-model" }
    func models(for providerID: String) -> [String] { ["test-model"] }
    func select(providerID: String, model: String?, reason: ModelSelectionReason) {}

    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var pendingResponse: CheckedContinuation<LLMResponse, Never>?
        private(set) var active = 0
        private(set) var finished = 0

        func begin(_ continuation: CheckedContinuation<LLMResponse, Never>) {
            lock.lock(); defer { lock.unlock() }
            active += 1
            pendingResponse = continuation
        }

        func end() {
            lock.lock(); defer { lock.unlock() }
            active -= 1
            finished += 1
        }

        func deliverLateResponse() {
            lock.lock()
            let continuation = pendingResponse
            pendingResponse = nil
            lock.unlock()
            continuation?.resume(returning: LLMResponse(content: "迟到的响应"))
        }
    }
}

private final class SlowLifecycleHooks: LifecycleHooksProviding {
    func addWillSendToLLMHook(_ hook: @escaping WillSendToLLMHook) -> any LifecycleHookHandle {
        NoopLifecycleHookHandle()
    }

    func addDidReceiveLLMResponseHook(_ hook: @escaping DidReceiveLLMResponseHook) {}
    func addTurnStartedHook(_ hook: @escaping TurnStartedHook) {}
    func addTurnFinishedHook(_ hook: @escaping TurnFinishedHook) {}
    func addWillExecuteToolHook(_ hook: @escaping WillExecuteToolHook) {}
    func addDidExecuteToolHook(_ hook: @escaping DidExecuteToolHook) {}

    func runWillSendToLLM(_ context: WillSendToLLMContext) async -> WillSendToLLMContext { context }
    func notifyDidReceiveLLMResponse(_ context: DidReceiveLLMResponseContext) async {}
    func notifyTurnStarted(_ context: TurnLifecycleContext) async {}
    func notifyWillExecuteTool(_ context: ProviderLifecycleHooks.ToolExecutionContext) async {}
    func notifyDidExecuteTool(_ context: ProviderLifecycleHooks.ToolExecutionContext) async {}

    func notifyTurnFinished(_ context: TurnLifecycleContext) async {
        try? await Task.sleep(nanoseconds: 40_000_000)
    }
}

private final class NoopLifecycleHookHandle: LifecycleHookHandle {
    func cancel() {}
}
