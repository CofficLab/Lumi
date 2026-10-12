import Foundation
import ProviderAgentLoop
import ProviderMessage

/// 监听 AgentLoop 事件并在可重试失败后自动重启回合。
///
/// 职责：
/// - 订阅 AgentLoop 事件，跟踪每个会话的重试状态；
/// - 校验失败是否可重试、是否达到最大尝试次数；
/// - 通过 `retryTurn`（带失败回合 ID 校验）重启回合；
/// - 每次重试在时间线写入一条系统消息（不进入 LLM 上下文）。
@MainActor
final class AgentLoopRetryCoordinator {
    /// 单个会话的重试跟踪状态。
    struct RetryState {
        var attempts: Int
        var failedTurnID: UUID
        var retryStartPending = false
        var retryTask: Task<Void, Never>?
    }

    private let agentLoop: any AgentLoopProviding
    private let messages: any MessageManaging
    private let maxAttempts: Int
    private var observerHandle: (any AgentLoopObserverHandle)?
    private var states: [UUID: RetryState] = [:]

    init(
        agentLoop: any AgentLoopProviding,
        messages: any MessageManaging,
        maxAttempts: Int
    ) {
        self.agentLoop = agentLoop
        self.messages = messages
        self.maxAttempts = max(0, maxAttempts)
        observerHandle = agentLoop.addAgentLoopObserver { [weak self] event in
            self?.handle(event)
        }
    }

    func cancel() {
        observerHandle?.cancel()
        observerHandle = nil
        states.values.forEach { $0.retryTask?.cancel() }
        states.removeAll()
    }

    private func handle(_ event: AgentLoopEvent) {
        switch event {
        case .started(let conversationID, let turnID):
            guard var state = states[conversationID] else { return }
            if state.retryStartPending {
                state.retryStartPending = false
                state.failedTurnID = turnID
                states[conversationID] = state
            } else {
                // A start not initiated by this coordinator begins a new retry chain.
                state.retryTask?.cancel()
                states.removeValue(forKey: conversationID)
            }

        case .failed(let conversationID, let turnID, _):
            handleFailure(conversationID: conversationID, turnID: turnID)

        case .completed(let conversationID, _),
             .cancelled(let conversationID, _):
            clearState(for: conversationID)

        case .toolCallsReceived, .llmResponseReceived, .suspended:
            break
        }
    }

    private func handleFailure(conversationID: UUID, turnID: UUID) {
        guard let failure = agentLoop.lastFailure(for: conversationID),
              failure.isRetryable,
              maxAttempts > 0 else {
            clearState(for: conversationID)
            return
        }

        let completedAttempts = states[conversationID]?.attempts ?? 0
        guard completedAttempts < maxAttempts else {
            clearState(for: conversationID)
            return
        }

        if states[conversationID]?.retryStartPending == true {
            states[conversationID]?.retryTask?.cancel()
        }
        states[conversationID] = RetryState(
            attempts: completedAttempts + 1,
            failedTurnID: turnID,
            retryStartPending: true,
            retryTask: nil
        )

        states[conversationID]?.retryTask = Task { @MainActor [weak self] in
            await self?.performRetry(
                conversationID: conversationID,
                failedTurnID: turnID,
                attempt: completedAttempts + 1,
                failure: failure
            )
        }
    }

    private func performRetry(
        conversationID: UUID,
        failedTurnID: UUID,
        attempt: Int,
        failure: AgentLoopFailure
    ) async {
        guard !Task.isCancelled,
              let state = states[conversationID],
              state.attempts == attempt,
              state.failedTurnID == failedTurnID,
              state.retryStartPending,
              agentLoop.state(for: conversationID) == .failed else {
            return
        }

        messages.insertMessage(
            AgentLoopRetryTimeline.message(
                conversationID: conversationID,
                failedTurnID: failedTurnID,
                attempt: attempt,
                maxAttempts: maxAttempts,
                failure: failure
            ),
            to: conversationID
        )

        do {
            let outcome = try await agentLoop.retryTurn(
                in: conversationID,
                after: failedTurnID
            )
            switch outcome {
            case .completed, .cancelled:
                clearState(for: conversationID)
            case .suspended:
                guard var current = states[conversationID], current.attempts == attempt else { return }
                current.retryStartPending = false
                current.retryTask = nil
                states[conversationID] = current
            case .failed:
                // The corresponding failed event owns the next retry transition.
                break
            }
        } catch {
            guard let current = states[conversationID], current.attempts == attempt else { return }
            AgentLoopRetryPlugin.logger.warning(
                "Retry request rejected for conversation \(conversationID.uuidString): \(error.localizedDescription)"
            )
            states.removeValue(forKey: conversationID)
        }
    }

    private func clearState(for conversationID: UUID) {
        states[conversationID]?.retryTask?.cancel()
        states.removeValue(forKey: conversationID)
    }
}