import Foundation
import ProviderAgentLoop
import ProviderConversationState
import ProviderLifecycleHooks
import ProviderMessage
import Testing
@testable import PluginConversationState

@Suite("PluginConversationState")
struct PluginConversationStateTests {
    @Test @MainActor
    func pluginMetadataIsStable() {
        let plugin = ConversationStatePlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.conversation-state")
        #expect(plugin.order == 10)
        #expect(plugin.metadata.policy == .alwaysOn)
    }

    @Test
    @MainActor
    func providerPublishesStateEvents() {
        let provider = ConversationStateProvider()
        let conversationID = UUID()
        var events: [ConversationStateEvent] = []
        let handle = provider.addConversationStateObserver { events.append($0) }

        provider.update(conversationID: conversationID, agentLoopState: .running)
        provider.remove(conversationID: conversationID)

        #expect(events == [.updated(conversationID), .removed(conversationID)])
        handle.cancel()
    }

    @Test
    @MainActor
    func partialUpdatePreservesUnchangedFields() {
        let provider = ConversationStateProvider()
        let conversationID = UUID()
        let turnID = UUID()

        provider.update(
            conversationID: conversationID,
            turnID: turnID,
            agentLoopState: .running,
            toolState: .executing,
            authorizationState: .required,
            activity: .thinking,
            lastError: "boom"
        )

        provider.update(conversationID: conversationID, toolState: .completed)

        let snapshot = provider.state(for: conversationID)
        #expect(snapshot.turnID == turnID)
        #expect(snapshot.agentLoopState == .running)
        #expect(snapshot.toolState == .completed)
        #expect(snapshot.activity == .thinking)
        #expect(snapshot.authorizationState == .required)
        #expect(snapshot.lastError == "boom")
        #expect(snapshot.isSending)
    }

    @Test
    @MainActor
    func clearFlagsResetActivityAndErrorWithoutTouchingOtherFields() {
        let provider = ConversationStateProvider()
        let conversationID = UUID()

        provider.update(
            conversationID: conversationID,
            agentLoopState: .running,
            activity: .sending,
            lastError: "stale"
        )
        provider.update(conversationID: conversationID, clearActivity: true, clearError: true)

        let snapshot = provider.state(for: conversationID)
        #expect(snapshot.activity == nil)
        #expect(snapshot.lastError == nil)
        #expect(snapshot.agentLoopState == .running)
    }

    @Test
    @MainActor
    func stateForUnknownConversationReturnsIdleDefault() {
        let provider = ConversationStateProvider()

        let snapshot = provider.state(for: UUID())

        #expect(snapshot.turnID == nil)
        #expect(snapshot.agentLoopState == .idle)
        #expect(snapshot.toolState == .idle)
        #expect(snapshot.authorizationState == .none)
        #expect(snapshot.activity == nil)
        #expect(snapshot.lastError == nil)
        #expect(!snapshot.isSending)
        #expect(!snapshot.jobActivity.hasJobs)
    }

    @Test
    @MainActor
    func removeUnknownConversationDoesNotNotify() {
        let provider = ConversationStateProvider()
        var events: [ConversationStateEvent] = []
        let handle = provider.addConversationStateObserver { events.append($0) }

        provider.remove(conversationID: UUID())

        #expect(events.isEmpty)
        handle.cancel()
    }

    @Test
    @MainActor
    func observerStopsReceivingAfterCancel() {
        let provider = ConversationStateProvider()
        var count = 0
        let handle = provider.addConversationStateObserver { _ in count += 1 }

        handle.cancel()
        provider.update(conversationID: UUID(), agentLoopState: .running)

        #expect(count == 0)
    }

    @Test
    @MainActor
    func jobActivityMergesIntoSnapshot() {
        let provider = ConversationStateProvider()
        let conversationID = UUID()

        provider.update(
            conversationID: conversationID,
            jobActivity: ConversationJobActivity(
                currentJobCount: 3,
                runningJobCount: 2,
                recentJobDescription: "build"
            )
        )

        let activity = provider.state(for: conversationID).jobActivity
        #expect(activity.currentJobCount == 3)
        #expect(activity.runningJobCount == 2)
        #expect(activity.recentJobDescription == "build")
        #expect(activity.hasJobs)
    }

    @Test("恢复后的迟到 suspended 事件不会覆盖运行中状态")
    @MainActor
    func lateSuspendedEventDoesNotOverwriteResumedTurnState() {
        let conversationID = UUID()
        let turnID = UUID()
        let suspension = AgentLoopSuspension(
            suspensionID: "userInput:ask-1",
            conversationID: conversationID,
            toolCallID: "ask-1",
            kind: "userInput",
            payload: "{\"question\":\"继续吗？\"}"
        )
        let loop = TestAgentLoop()
        loop.activeTurnID = turnID
        loop.activeSuspension = suspension
        loop.currentState = .suspended
        let provider = ConversationStateProvider()
        let observer = AgentLoopStateObserver(agentLoop: loop, provider: provider)

        // 旧回合先挂起；用户回答后，恢复后的 LLM step 已经产生工具调用，
        // 因而状态应当重新是 running。
        loop.emit(.suspended(
            conversationID: conversationID,
            turnID: turnID,
            suspension: suspension
        ))
        loop.emit(.toolCallsReceived(
            conversationID: conversationID,
            turnID: turnID,
            assistantMessageID: UUID(),
            toolCalls: [MessageToolCall(
                id: "run-1",
                name: "run_command",
                arguments: "{\"command\":\"pwd\"}"
            )]
        ))
        loop.currentState = .running
        #expect(provider.state(for: conversationID).agentLoopState == .running)

        // 模拟 finishTurn 中延迟投递的旧 suspended 通知到达。
        loop.emit(.suspended(
            conversationID: conversationID,
            turnID: turnID,
            suspension: suspension
        ))

        #expect(provider.state(for: conversationID).agentLoopState == .running)
        #expect(provider.state(for: conversationID).activity == .executingTool)
        observer.cancel()
    }
}

@MainActor
private final class TestAgentLoop: AgentLoopProviding {
    private var callback: ((AgentLoopEvent) -> Void)?
    var currentState: AgentLoopState = .running
    var activeTurnID: UUID?
    var activeSuspension: AgentLoopSuspension?

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        self.callback = callback
        return TestAgentLoopObserverHandle { [weak self] in
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

    func lastFailure(for conversationID: UUID) -> AgentLoopFailure? { nil }

    func isRunning(for conversationID: UUID) -> Bool { true }

    func currentTurnID(for conversationID: UUID) -> UUID? { activeTurnID }

    func isAutoReplySuppressed(for conversationID: UUID) -> Bool { false }

    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {}

    func retryTurn(
        in conversationID: UUID,
        after failedTurnID: UUID
    ) async throws -> AgentLoopOutcome { .completed }

    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class TestAgentLoopObserverHandle: AgentLoopObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}
