import Foundation
import KernelCore
import KitSuperLog
import os
import ProviderAgentLoop
import ProviderMessage

/// 自动恢复可重试 AgentLoop 失败的插件。
///
/// 插件不介入 AgentLoop 内部执行，只消费最终失败事件：
/// 1. 查询结构化失败详情；
/// 2. 判断是否允许自动重试；
/// 3. 写入一条不会进入 LLM 上下文的时间线消息；
/// 4. 通过带失败回合 ID 校验的 `retryTurn` 重新启动回合。
@MainActor
public final class AgentLoopRetryPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.agent-loop-retry",
        category: "AgentLoopRetryPlugin"
    )

    public static let defaultMaxAttempts = 3

    public let id = "com.coffic.lumi.plugin.agent-loop-retry"
    public let order = 9
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.agent-loop-retry",
        name: "Agent Loop Retry",
        description: "Retries transient AgentLoop failures and records each attempt in the conversation timeline.",
        category: .core,
        stage: .preview,
        policy: .alwaysOn
    )

    private var coordinator: AgentLoopRetryCoordinator?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self),
              let messages = kernel.resolveProvider((any MessageManaging).self) else {
            Self.logger.error("\(Self.t)Required AgentLoopProviding or MessageManaging is unavailable")
            return
        }

        coordinator?.cancel()
        coordinator = AgentLoopRetryCoordinator(
            agentLoop: agentLoop,
            messages: messages,
            maxAttempts: Self.defaultMaxAttempts
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        coordinator?.cancel()
        coordinator = nil
    }
}

@MainActor
final class AgentLoopRetryCoordinator {
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
            makeRetryTimelineMessage(
                conversationID: conversationID,
                failedTurnID: failedTurnID,
                attempt: attempt,
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

    private func makeRetryTimelineMessage(
        conversationID: UUID,
        failedTurnID: UUID,
        attempt: Int,
        failure: AgentLoopFailure
    ) -> Message {
        var metadata: [String: String] = [
            MessageTimelineEvent.metadataKey: MessageTimelineEvent.agentLoopRetry,
            MessageTimelineEvent.agentLoopRetryAttemptKey: "\(attempt)",
            MessageTimelineEvent.agentLoopRetryMaxAttemptsKey: "\(maxAttempts)",
            MessageTimelineEvent.agentLoopRetryReasonKey: failure.message,
            MessageTimelineEvent.agentLoopRetryKindKey: failure.kind.rawValue,
        ]
        if let providerID = failure.providerID {
            metadata[MessageTimelineEvent.agentLoopRetryProviderIDKey] = providerID
        }
        if let modelName = failure.modelName {
            metadata[MessageTimelineEvent.agentLoopRetryModelNameKey] = modelName
        }
        if let statusCode = failure.httpStatusCode {
            metadata[MessageTimelineEvent.agentLoopRetryHTTPStatusCodeKey] = "\(statusCode)"
        }

        let reason = failure.message.isEmpty ? failure.kind.rawValue : failure.message
        return Message(
            conversationID: conversationID,
            role: .system,
            content: "正在重试 Agent 回合（\(attempt)/\(maxAttempts)）：\(reason)",
            turnID: failedTurnID,
            metadata: metadata,
            providerID: failure.providerID,
            modelName: failure.modelName,
            rawErrorDetail: failure.message,
            httpStatusCode: failure.httpStatusCode,
            renderKind: MessageTimelineEvent.agentLoopRetryRenderKind,
            preferredRendererID: "core-agent-loop-retry"
        )
    }
}
