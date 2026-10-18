import Foundation

/// 监听 AgentLoop 事件并在可重试失败后自动重启回合。
///
/// 职责：
/// - 订阅 AgentLoop 事件，跟踪每个会话的重试状态；
/// - 校验失败是否可重试、是否达到最大尝试次数；
/// - 通过 `retryTurn`（带失败回合 ID 校验）重启回合；
/// - 每次重试在时间线写入一条系统消息（不进入 LLM 上下文）。
///
/// 重试预算按**连续失败**计费：同一回合内只要 LLM 成功返回过一次
/// （工具调用或正文），预算即回到满额，只有背靠背的失败才会消耗次数。
@MainActor
final class AgentLoopRetryCoordinator {
    /// 单个会话的重试跟踪状态。
    struct RetryState {
        var attempts: Int
        var failedTurnID: UUID
        var retryStartPending = false
        var retryTask: Task<Void, Never>?
    }

    private let loop: AgentLoopRetryCapability
    private let messages: AgentLoopRetryMessageCapability
    private let maxAttempts: Int
    private var observerHandle: (any AgentLoopRetryObserverHandle)?
    private var states: [UUID: RetryState] = [:]

    init(
        loop: AgentLoopRetryCapability,
        messages: AgentLoopRetryMessageCapability,
        maxAttempts: Int
    ) {
        self.loop = loop
        self.messages = messages
        self.maxAttempts = max(0, maxAttempts)
        observerHandle = loop.addTurnObserver { [weak self] event in
            self?.handle(event)
        }
    }

    func cancel() {
        observerHandle?.cancel()
        observerHandle = nil
        states.values.forEach { $0.retryTask?.cancel() }
        states.removeAll()
    }

    private func handle(_ event: AgentLoopRetryEvent) {
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

        case .failed(let conversationID, let turnID):
            handleFailure(conversationID: conversationID, turnID: turnID)

        case .settled(let conversationID):
            clearState(for: conversationID)

        case .progressReceived(let conversationID):
            // LLM 成功返回过一次（工具调用或正文）。回合仍在进行中，但失败
            // 已经不再是背靠背的，重试预算回到满额。
            resetAttempts(for: conversationID)
        }
    }

    /// 成功响应后把重试预算恢复到满额。
    ///
    /// 只清零计数：失败回合身份、待启动标记和正在进行的重试任务都属于当前
    /// 重试链，必须保留，否则会丢失已经发出的重试或让后续失败无法接续。
    private func resetAttempts(for conversationID: UUID) {
        guard var state = states[conversationID], state.attempts > 0 else { return }
        state.attempts = 0
        states[conversationID] = state
    }

    private func handleFailure(conversationID: UUID, turnID: UUID) {
        guard let failure = loop.lastFailure(for: conversationID),
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
        failure: AgentLoopRetryFailure
    ) async {
        guard !Task.isCancelled,
              let state = states[conversationID],
              state.attempts == attempt,
              state.failedTurnID == failedTurnID,
              state.retryStartPending,
              loop.turnState(for: conversationID) == .failed else {
            return
        }

        messages.insertRetryNotice(
            AgentLoopRetryTimeline.message(
                conversationID: conversationID,
                failedTurnID: failedTurnID,
                attempt: attempt,
                maxAttempts: maxAttempts,
                failure: failure
            )
        )

        do {
            let outcome = try await loop.retryTurn(
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