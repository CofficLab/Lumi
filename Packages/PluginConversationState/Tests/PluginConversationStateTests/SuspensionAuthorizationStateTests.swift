import Foundation
import ProviderAgentLoop
import ProviderConversationState
import ProviderLifecycleHooks
import ProviderMessage
import Testing
@testable import PluginConversationState

/// 执行期授权（如 Computer Use 应用授权）与 `ask_user` 共用 `.suspended`
/// 这一个 AgentLoop 事件，但语义不同：
///
/// - 授权挂起等的是「允许 / 拒绝」，会话列表应显示授权盾牌
///   （`authorizationState == .required`）；
/// - `ask_user` 等的是用户回答，不应被标成授权等待。
///
/// 执行期授权不经过 `ToolManagerEvent.authorizationRequired`，因此这条
/// 会话级状态只能由 `AgentLoopStateObserver` 依据挂起载荷写入。
@Suite("执行期授权状态")
struct SuspensionAuthorizationStateTests {

    @Test("执行期授权挂起必须把会话授权状态标记为 required（#961）")
    @MainActor
    func authorizationSuspensionMarksAuthorizationRequired() {
        let conversationID = UUID()
        let turnID = UUID()
        let suspension = AgentLoopSuspension(
            suspensionID: "userInput:call_cu_1",
            conversationID: conversationID,
            toolCallID: "call_cu_1",
            kind: "userInput",
            payload: #"{"toolCallId":"call_cu_1","kind":"computer_use_authorization","question":"Allow?","options":["Allow"],"mode":"yes_no"}"#
        )
        let loop = SuspensionTestAgentLoop()
        loop.currentState = .suspended
        loop.activeTurnID = turnID
        loop.activeSuspension = suspension
        let provider = ConversationStateProvider()
        let observer = AgentLoopStateObserver(agentLoop: loop, provider: provider)

        loop.emit(.suspended(
            conversationID: conversationID,
            turnID: turnID,
            suspension: suspension
        ))

        let snapshot = provider.state(for: conversationID)
        #expect(snapshot.agentLoopState == .suspended)
        #expect(snapshot.activity == .waitingForUser)
        #expect(
            snapshot.authorizationState == .required,
            "执行期授权挂起未标记 required，会话列表只能显示普通暂停"
        )
        observer.cancel()
    }

    @Test("ask_user 挂起不得被误标为授权等待")
    @MainActor
    func askUserSuspensionKeepsAuthorizationNone() {
        let conversationID = UUID()
        let turnID = UUID()
        let suspension = AgentLoopSuspension(
            suspensionID: "userInput:ask_1",
            conversationID: conversationID,
            toolCallID: "ask_1",
            kind: "userInput",
            payload: #"{"toolCallId":"ask_user","question":"继续吗？"}"#
        )
        let loop = SuspensionTestAgentLoop()
        loop.currentState = .suspended
        loop.activeTurnID = turnID
        loop.activeSuspension = suspension
        let provider = ConversationStateProvider()
        let observer = AgentLoopStateObserver(agentLoop: loop, provider: provider)

        loop.emit(.started(conversationID: conversationID, turnID: turnID))
        loop.emit(.suspended(
            conversationID: conversationID,
            turnID: turnID,
            suspension: suspension
        ))

        let snapshot = provider.state(for: conversationID)
        #expect(snapshot.agentLoopState == .suspended)
        #expect(
            snapshot.authorizationState == .none,
            "ask_user 等的是回答，不应显示授权盾牌"
        )
        observer.cancel()
    }

    @Test("用户做出决定后会话授权状态必须回落")
    @MainActor
    func resumedTurnClearsAuthorizationRequired() {
        let conversationID = UUID()
        let turnID = UUID()
        let suspension = AgentLoopSuspension(
            suspensionID: "userInput:call_cu_2",
            conversationID: conversationID,
            toolCallID: "call_cu_2",
            kind: "userInput",
            payload: #"{"toolCallId":"call_cu_2","kind":"computer_use_authorization","question":"Allow?","options":["Allow"],"mode":"yes_no"}"#
        )
        let loop = SuspensionTestAgentLoop()
        loop.currentState = .suspended
        loop.activeTurnID = turnID
        loop.activeSuspension = suspension
        let provider = ConversationStateProvider()
        let observer = AgentLoopStateObserver(agentLoop: loop, provider: provider)

        loop.emit(.suspended(
            conversationID: conversationID,
            turnID: turnID,
            suspension: suspension
        ))
        #expect(provider.state(for: conversationID).authorizationState == .required)

        // 用户点了「允许」：回合恢复并进入下一批工具调用，授权不再等待。
        loop.currentState = .running
        loop.activeSuspension = nil
        loop.emit(.toolCallsReceived(
            conversationID: conversationID,
            turnID: turnID,
            assistantMessageID: UUID(),
            toolCalls: [MessageToolCall(id: "run-1", name: "read_file", arguments: "{}")]
        ))

        #expect(
            provider.state(for: conversationID).authorizationState == .none,
            "授权已解决，会话列表不应继续显示授权盾牌"
        )
        observer.cancel()
    }
}

@MainActor
private final class SuspensionTestAgentLoop: AgentLoopProviding {
    private var callback: ((AgentLoopEvent) -> Void)?
    var currentState: AgentLoopState = .running
    var activeTurnID: UUID?
    var activeSuspension: AgentLoopSuspension?

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        self.callback = callback
        return SuspensionTestObserverHandle { [weak self] in
            self?.callback = nil
        }
    }

    func emit(_ event: AgentLoopEvent) {
        callback?(event)
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }

    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome { .completed }

    func cancelTurn(in conversationID: UUID) {}

    func state(for conversationID: UUID) -> AgentLoopState { currentState }

    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { activeSuspension }

    func isRunning(for conversationID: UUID) -> Bool { true }

    func currentTurnID(for conversationID: UUID) -> UUID? { activeTurnID }

    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class SuspensionTestObserverHandle: AgentLoopObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}
