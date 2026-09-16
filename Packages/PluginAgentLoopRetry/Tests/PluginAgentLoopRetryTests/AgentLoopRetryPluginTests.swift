import Foundation
import Testing
@testable import PluginAgentLoopRetry
import ProviderAgentLoop
import ProviderLifecycleHooks
import ProviderMessage

@MainActor
struct AgentLoopRetryPluginTests {
    @Test("可重试失败最多自动重试三次并记录完整时间线")
    func retriesTransientFailureThreeTimes() async {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let agentLoop = TestAgentLoop(outcomes: [
            .failed("network"),
            .failed("network"),
            .failed("network"),
        ])
        let coordinator = AgentLoopRetryCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            maxAttempts: 3
        )

        agentLoop.failure = AgentLoopFailure(
            kind: .network,
            message: "连接被重置",
            providerID: "openai",
            modelName: "gpt-5",
            httpStatusCode: 503
        )
        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: "连接被重置"))
        await yieldUntil { agentLoop.retryCalls.count == 3 }

        let retryMessages = messages.messages(for: conversationID)
            .filter(MessageTimelineEvent.isAgentLoopRetry)
        #expect(agentLoop.retryCalls.count == 3)
        #expect(retryMessages.count == 3)
        #expect(retryMessages.compactMap {
            MessageTimelineEvent.integerMetadata(
                MessageTimelineEvent.agentLoopRetryAttemptKey,
                from: $0
            )
        } == [1, 2, 3])
        #expect(retryMessages.allSatisfy { $0.role == .system })
        #expect(retryMessages[0].metadata[MessageTimelineEvent.agentLoopRetryProviderIDKey] == "openai")
        #expect(retryMessages[0].metadata[MessageTimelineEvent.agentLoopRetryModelNameKey] == "gpt-5")
        #expect(retryMessages[0].metadata[MessageTimelineEvent.agentLoopRetryHTTPStatusCodeKey] == "503")

        coordinator.cancel()
    }

    @Test("不可重试失败不会启动重试")
    func doesNotRetryNonRetryableFailure() async {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let agentLoop = TestAgentLoop()
        let coordinator = AgentLoopRetryCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            maxAttempts: 3
        )

        agentLoop.failure = AgentLoopFailure(
            kind: .authentication,
            message: "API key missing"
        )
        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: "API key missing"))
        await Task.yield()

        #expect(agentLoop.retryCalls.isEmpty)
        #expect(messages.messages(for: conversationID).isEmpty)
        coordinator.cancel()
    }

    @Test("完成后新失败链从第一次重试重新计数")
    func resetsAfterSuccessfulRetry() async {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let agentLoop = TestAgentLoop(outcomes: [.completed, .completed])
        let coordinator = AgentLoopRetryCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            maxAttempts: 3
        )
        let failure = AgentLoopFailure(kind: .network, message: "暂时不可用")
        agentLoop.failure = failure

        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: failure.message))
        await yieldUntil { agentLoop.retryCalls.count == 1 }
        agentLoop.emit(.failed(conversationID: conversationID, turnID: UUID(), reason: failure.message))
        await yieldUntil { agentLoop.retryCalls.count == 2 }

        let attempts = messages.messages(for: conversationID)
            .filter(MessageTimelineEvent.isAgentLoopRetry)
            .compactMap {
                MessageTimelineEvent.integerMetadata(
                    MessageTimelineEvent.agentLoopRetryAttemptKey,
                    from: $0
                )
            }
        #expect(attempts == [1, 1])
        coordinator.cancel()
    }
}

@MainActor
private final class TestAgentLoop: AgentLoopProviding {
    struct RetryCall {
        let conversationID: UUID
        let failedTurnID: UUID
    }

    var failure: AgentLoopFailure?
    var outcomes: [AgentLoopOutcome]
    private var observers: [UUID: (AgentLoopEvent) -> Void] = [:]
    private(set) var retryCalls: [RetryCall] = []
    private var stateValue: AgentLoopState = .failed

    init(outcomes: [AgentLoopOutcome] = [.failed("network")]) {
        self.outcomes = outcomes
    }

    @discardableResult
    func addAgentLoopObserver(_ callback: @escaping (AgentLoopEvent) -> Void) -> any AgentLoopObserverHandle {
        let id = UUID()
        observers[id] = callback
        return Handle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        .completed
    }

    func cancelTurn(in conversationID: UUID) {
        stateValue = .cancelled
        emit(.cancelled(conversationID: conversationID, turnID: nil))
    }

    func state(for conversationID: UUID) -> AgentLoopState { stateValue }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func lastFailure(for conversationID: UUID) -> AgentLoopFailure? { failure }
    func isRunning(for conversationID: UUID) -> Bool { stateValue == .running }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}

    func retryTurn(in conversationID: UUID, after failedTurnID: UUID) async throws -> AgentLoopOutcome {
        retryCalls.append(RetryCall(conversationID: conversationID, failedTurnID: failedTurnID))
        let turnID = UUID()
        stateValue = .running
        emit(.started(conversationID: conversationID, turnID: turnID))
        let outcome = outcomes.isEmpty ? .completed : outcomes.removeFirst()
        switch outcome {
        case .completed:
            stateValue = .completed
            emit(.completed(conversationID: conversationID, turnID: turnID))
        case .failed(let reason):
            stateValue = .failed
            emit(.failed(conversationID: conversationID, turnID: turnID, reason: reason))
        case .cancelled:
            stateValue = .cancelled
            emit(.cancelled(conversationID: conversationID, turnID: turnID))
        case .suspended:
            stateValue = .suspended
            emit(.suspended(
                conversationID: conversationID,
                turnID: turnID,
                suspension: AgentLoopSuspension(
                    suspensionID: "test",
                    conversationID: conversationID,
                    kind: "test",
                    payload: "{}"
                )
            ))
        }
        return outcome
    }

    func emit(_ event: AgentLoopEvent) {
        if case .failed = event {
            stateValue = .failed
        }
        for observer in observers.values {
            observer(event)
        }
    }

    private final class Handle: AgentLoopObserverHandle {
        private let cancellation: () -> Void

        init(_ cancellation: @escaping () -> Void) {
            self.cancellation = cancellation
        }

        func cancel() {
            cancellation()
        }
    }
}

@MainActor
private func yieldUntil(
    _ condition: @escaping @MainActor () -> Bool
) async {
    for _ in 0..<100 where !condition() {
        try? await Task.sleep(for: .milliseconds(1))
    }
}
