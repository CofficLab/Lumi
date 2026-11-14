import Foundation
import ProviderAgentLoop
import ProviderConversationState
import ProviderLifecycleHooks
import ProviderMessage
import Testing
@testable import PluginConversationState

/// 锁定终态事件的回合身份校验（#438）。
///
/// AgentLoop 的终态通知异步投递：取消旧回合 A 后立即开始新回合 B，
/// A 的迟到 completed/failed/cancelled 不得把 B 的 running 状态覆盖成终态。
@Suite("会话状态迟到终态（#438）")
@MainActor
struct StaleTerminalStateTests {

    @Test("旧回合的迟到 completed 不得覆盖新回合的 running 状态")
    func staleCompletedDoesNotOverwriteRunningTurn() {
        let fixture = StateFixture()
        let conversationID = UUID()
        let turnA = UUID()
        let turnB = UUID()

        fixture.loop.emit(.started(conversationID: conversationID, turnID: turnB))
        #expect(fixture.provider.state(for: conversationID).agentLoopState == .running)

        fixture.loop.emit(.completed(conversationID: conversationID, turnID: turnA))
        let snapshot = fixture.provider.state(for: conversationID)
        #expect(snapshot.agentLoopState == .running)
        #expect(snapshot.turnID == turnB)
        #expect(snapshot.activity == .thinking)

        fixture.loop.emit(.completed(conversationID: conversationID, turnID: turnB))
        #expect(fixture.provider.state(for: conversationID).agentLoopState == .completed)
    }

    @Test("旧回合的迟到 failed/cancelled 不得覆盖新回合状态")
    func staleFailedAndCancelledDoNotOverwriteRunningTurn() {
        let fixture = StateFixture()
        let conversationID = UUID()
        let turnA = UUID()
        let turnB = UUID()

        fixture.loop.emit(.started(conversationID: conversationID, turnID: turnB))
        fixture.loop.emit(.failed(conversationID: conversationID, turnID: turnA, reason: "old failure"))
        fixture.loop.emit(.cancelled(conversationID: conversationID, turnID: turnA))

        let snapshot = fixture.provider.state(for: conversationID)
        #expect(snapshot.agentLoopState == .running)
        #expect(snapshot.turnID == turnB)
        #expect(snapshot.lastError == nil)
    }

    @Test("旧回合的迟到工具事件不得改写新回合的 turnID 与活动")
    func staleToolCallsDoNotOverwriteTurn() {
        let fixture = StateFixture()
        let conversationID = UUID()
        let turnA = UUID()
        let turnB = UUID()

        fixture.loop.emit(.started(conversationID: conversationID, turnID: turnB))
        fixture.loop.emit(.toolCallsReceived(
            conversationID: conversationID,
            turnID: turnA,
            assistantMessageID: UUID(),
            toolCalls: [MessageToolCall(id: "call-1", name: "run_command", arguments: "{}")]
        ))

        let snapshot = fixture.provider.state(for: conversationID)
        #expect(snapshot.turnID == turnB)
        #expect(snapshot.activity == .thinking)
    }

    @Test("快照未记录 turnID 时终态保持旧行为")
    func terminalWithoutKnownTurnStillApplies() {
        let fixture = StateFixture()
        let conversationID = UUID()

        fixture.loop.emit(.completed(conversationID: conversationID, turnID: UUID()))
        #expect(fixture.provider.state(for: conversationID).agentLoopState == .completed)
    }
}

// MARK: - Fixture

@MainActor
private struct StateFixture {
    let loop = StaleTestAgentLoop()
    let provider = ConversationStateProvider()
    let observer: AgentLoopStateObserver

    init() {
        observer = AgentLoopStateObserver(agentLoop: loop, provider: provider)
    }
}

@MainActor
private final class StaleTestAgentLoop: AgentLoopProviding {
    private var callback: ((AgentLoopEvent) -> Void)?
    var currentState: AgentLoopState = .running
    var activeTurnID: UUID?
    var activeSuspension: AgentLoopSuspension?

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        self.callback = callback
        return Handle { [weak self] in self?.callback = nil }
    }

    func emit(_ event: AgentLoopEvent) { callback?(event) }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome { .completed }
    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { currentState }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { activeSuspension }
    func lastFailure(for conversationID: UUID) -> AgentLoopFailure? { nil }
    func isRunning(for conversationID: UUID) -> Bool { currentState == .running }
    func currentTurnID(for conversationID: UUID) -> UUID? { activeTurnID }
    func isAutoReplySuppressed(for conversationID: UUID) -> Bool { false }
    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {}
    func retryTurn(in conversationID: UUID, after failedTurnID: UUID) async throws -> AgentLoopOutcome { .completed }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}

    private final class Handle: AgentLoopObserverHandle {
        private var cancellation: (() -> Void)?
        init(_ cancellation: @escaping () -> Void) { self.cancellation = cancellation }
        func cancel() { cancellation?(); cancellation = nil }
    }
}