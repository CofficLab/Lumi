import Foundation
import KitAgentTool
import KitLLM
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import Testing
@testable import PluginAgentLoop

/// 挂起回合的取消语义。
///
/// 挂起（等工具授权、等 `ask_user` 回答）同样是「回合还没干完」，
/// 用户必须在输入区能把它停掉。这组用例锁住三件事：
/// 1. 挂起回合可以被取消，且挂起点随之消失；
/// 2. 取消后消息里残留的授权占位必须写成终态，否则授权卡片会留在界面上
///    等一个已经不存在的回合作答；
/// 3. 恢复回合的过程中被取消，回合不得「复活」。
@MainActor
@Suite("挂起回合的取消")
struct SuspendedTurnCancellationTests {

    // MARK: - 取消挂起回合

    @Test("取消挂起回合后状态收敛到 cancelled 且挂起点消失")
    func cancellingSuspendedTurnClearsSuspension() {
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
                suspension: suspension(
                    conversationID: conversationID,
                    toolCallID: toolCallID
                )
            ),
            lastTurnID: turnID
        )
        #expect(loop.state(for: conversationID) == .suspended)

        loop.cancelTurn(in: conversationID)

        #expect(loop.state(for: conversationID) == .cancelled)
        #expect(loop.suspension(for: conversationID) == nil)
    }

    @Test("取消挂起回合时残留的授权占位写成 userRejected 终态")
    func cancellingSuspendedTurnSettlesAuthorizationPlaceholder() {
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
                suspension: suspension(
                    conversationID: conversationID,
                    toolCallID: toolCallID
                )
            ),
            lastTurnID: turnID
        )

        loop.cancelTurn(in: conversationID)

        // 授权卡片由「pendingAuthorization + 仍在等待用户响应」判定，
        // 两个条件都必须被打破，否则卡片会留在界面上等一个死掉的回合。
        let stored = messages.message(id: assistantMessageID, in: conversationID)?
            .toolCalls?.first(where: { $0.id == toolCallID })
        #expect(stored?.authorizationState == ToolCallAuthorizationState.userRejected.rawValue)
        #expect(stored?.result?.awaitingUserResponse == false)
    }

    @Test("取消挂起回合时终态事件必须投递出去")
    func cancellingSuspendedTurnDeliversCancelledEvent() async {
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
                suspension: suspension(
                    conversationID: conversationID,
                    toolCallID: toolCallID
                )
            ),
            lastTurnID: turnID
        )
        // 走真实的挂起路径：finishTurn(.suspended) 会把 completionDelivered 置为 true。
        // 少了这一步就复现不出线上那个 bug——它正是「挂起后取消，事件发不出去」的成因。
        //
        // 注意：这里必须用与 Reducer 产出的完全相同的 outcome，
        // finishTurn 的守门条件比较的是整个 AgentLoopOutcome（含关联值）。
        loop.finishTurn(
            conversationID: conversationID,
            turnID: turnID,
            outcome: .suspended("awaiting user response")
        )
        #expect(loop.runtimes[conversationID]?.completionDelivered == true)

        var cancelledEventCount = 0
        let observer = loop.addAgentLoopObserver { event in
            if case .cancelled = event { cancelledEventCount += 1 }
        }

        loop.cancelTurn(in: conversationID)

        // 终态通知是异步投递的，等主线程队列跑完。
        try? await Task.sleep(nanoseconds: 100_000_000)

        // 这个事件是界面回落的唯一依据：会话状态据此从 .suspended 变成 .cancelled，
        // 停止按钮才会消失、发送按钮才会回来。事件发不出去 = 用户按了停止没反应。
        #expect(cancelledEventCount == 1)
        #expect(loop.state(for: conversationID) == .cancelled)
        observer.cancel()
    }

    @Test("ask_user 挂起点不被误写成工具授权终态")
    func cancellingAskUserTurnKeepsAuthorizationStateUntouched() {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let turnID = UUID()
        let assistantMessageID = UUID()
        let toolCallID = "call_ask_1"
        let loop = makeLoop(messages: messages)
        // ask_user 不需要工具授权，授权状态是 autoApproved。
        messages.insertMessage(
            Message(
                id: assistantMessageID,
                conversationID: conversationID,
                role: .assistant,
                content: "",
                turnID: turnID,
                toolCalls: [
                    MessageToolCall(
                        id: toolCallID,
                        name: "ask_user",
                        arguments: "{}",
                        result: MessageToolResult(
                            content: #"{"question":"继续吗？"}"#,
                            awaitingUserResponse: true,
                            interactionState: .waiting
                        ),
                        authorizationState: ToolCallAuthorizationState.autoApproved.rawValue
                    )
                ]
            ),
            to: conversationID
        )
        loop.runtimes[conversationID] = TurnRuntime(
            phase: .awaitingUser(
                turnID: turnID,
                assistantMessageID: assistantMessageID,
                pendingToolCalls: [],
                suspension: suspension(
                    conversationID: conversationID,
                    toolCallID: toolCallID
                )
            ),
            lastTurnID: turnID
        )

        loop.cancelTurn(in: conversationID)

        let stored = messages.message(id: assistantMessageID, in: conversationID)?
            .toolCalls?.first(where: { $0.id == toolCallID })
        #expect(stored?.authorizationState == ToolCallAuthorizationState.autoApproved.rawValue)
    }

    // MARK: - 恢复过程中被取消

    @Test("恢复回合过程中被取消，回合不得复活")
    func cancellingDuringResumeDoesNotReviveTurn() async {
        let toolManager = BlockingResolveToolManager()
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let turnID = UUID()
        let assistantMessageID = UUID()
        let toolCallID = "call_approve_1"
        let loop = makeLoop(messages: messages, toolManager: toolManager)
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
                suspension: suspension(
                    conversationID: conversationID,
                    toolCallID: toolCallID
                )
            ),
            lastTurnID: turnID
        )

        let resumeTask = Task { @MainActor in
            do {
                return try await loop.resumeTurn(
                    in: conversationID,
                    request: AgentTurnResumeRequest(
                        suspensionID: "userInput:\(toolCallID)",
                        answer: "approved"
                    )
                )
            } catch {
                return AgentLoopOutcome.failed(error.localizedDescription)
            }
        }
        // 等恢复流程走到「正在解析用户响应」这一步。
        for _ in 0..<200 where !toolManager.didEnterResolve {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        #expect(toolManager.didEnterResolve)

        // 用户在这段窗口里按下停止。
        loop.cancelTurn(in: conversationID)
        toolManager.release()

        let outcome = await resumeTask.value
        #expect(outcome == .cancelled)
        // 旧实现会用进入 resumeTurn 时捕获的快照覆盖 .cancelled，
        // 把回合拽回 executingTools——用户按了停止，Agent 却继续跑。
        #expect(loop.state(for: conversationID) == .cancelled)
    }

    // MARK: - Support

    private func makeLoop(
        messages: any MessageManaging,
        toolManager: (any ToolManagerProviding)? = nil
    ) -> AgentLoopManager {
        AgentLoopManager(
            messages: messages,
            llmManager: DefaultLLMManager(),
            toolManager: toolManager ?? DefaultToolManagerProviding(),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager(),
            contextProvider: PassthroughLLMContextProvider(messages: messages)
        )
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

    private func suspension(conversationID: UUID, toolCallID: String) -> AgentLoopSuspension {
        AgentLoopSuspension(
            suspensionID: "userInput:\(toolCallID)",
            conversationID: conversationID,
            toolCallID: toolCallID,
            kind: "userInput",
            payload: "{}"
        )
    }
}

/// `resolveUserResponse` 会挂起等待的桩，用来把「恢复流程进行中」这个窗口固定住。
@MainActor
private final class BlockingResolveToolManager: ToolManagerProviding {
    private(set) var didEnterResolve = false
    private var continuation: CheckedContinuation<Void, Never>?

    func release() {
        continuation?.resume()
        continuation = nil
    }

    func resolveUserResponse(
        _ answer: String,
        for toolCall: KitAgentTool.ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        didEnterResolve = true
        await withCheckedContinuation { continuation = $0 }
        return ToolCallResult(content: answer)
    }

    @discardableResult
    func addToolManagerObserver(
        _ callback: @escaping (ToolManagerEvent) -> Void
    ) -> any ToolManagerObserverHandle {
        NoopToolManagerObserverHandle()
    }

    @discardableResult
    func addToolJobObserver(
        _ callback: @escaping (ToolJobEvent) -> Void
    ) -> any ToolJobObserverHandle {
        NoopToolJobObserverHandle()
    }

    func allTools() -> [any SuperAgentTool] { [] }
    func add(_ tool: any SuperAgentTool, pluginID: String) {}
    func remove(id: String) {}
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
    func tool(named name: String) -> (any SuperAgentTool)? { nil }
    func displayDescription(for toolCall: KitAgentTool.ToolCall) -> String? { nil }
    func riskLevel(for toolCall: KitAgentTool.ToolCall) -> CommandRiskLevel? { nil }
    func authorizationDecision(
        for toolCall: KitAgentTool.ToolCall,
        conversationID: UUID
    ) -> ToolAuthorizationDecision { .autoApproved }
    func execute(
        _ toolCall: KitAgentTool.ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult { ToolCallResult(content: "unused") }
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
    func deleteToolCalls(for conversationID: UUID) async {}
    func cancelJobs(forTurnID turnID: UUID) {}
}

@MainActor
private final class NoopToolManagerObserverHandle: ToolManagerObserverHandle {
    func cancel() {}
}

@MainActor
private final class NoopToolJobObserverHandle: ToolJobObserverHandle {
    func cancel() {}
}
