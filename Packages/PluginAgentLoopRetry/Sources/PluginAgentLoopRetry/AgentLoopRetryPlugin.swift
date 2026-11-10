import Foundation
import KernelCore
import LumiLoggingKit
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage

/// 自动恢复可重试 AgentLoop 失败的插件。
///
/// 插件不介入 AgentLoop 内部执行，只消费最终失败事件：
/// 1. 查询结构化失败详情；
/// 2. 判断是否允许自动重试；
/// 3. 写入一条不会进入 LLM 上下文的时间线消息；
/// 4. 通过带失败回合 ID 校验的 `retryTurn` 重新启动回合。
@MainActor
public final class AgentLoopRetryPlugin: SuperPlugin, SuperLog, AgentLoopRetryLifecycleProviding {
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
    private var lifecycleObservers: [UUID: (AgentLoopRetryLifecycleEvent) -> Void] = [:]

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self),
              let messages = kernel.resolveProvider((any MessageManaging).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Self.logger.error("\(Self.t)Required AgentLoopProviding, MessageManaging or ConversationManaging is unavailable")
            return
        }

        coordinator?.cancel()
        coordinator = AgentLoopRetryCoordinator(
            loop: AgentLoopRetryCapabilityAdapter(agentLoop: agentLoop, conversations: conversations),
            messages: AgentLoopRetryMessageCapabilityAdapter(messages: messages),
            maxAttempts: Self.defaultMaxAttempts,
            onLifecycleEvent: { [weak self] event in
                self?.publishLifecycleEvent(event)
            }
        )

        // 上层桥接器（如 ACP）通过该 Provider 判断失败是否会被重试接管。
        let lifecycleType = (any AgentLoopRetryLifecycleProviding).self
        if !kernel.isProviderRegistered(lifecycleType) {
            try kernel.registerProvider(lifecycleType, self)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        coordinator?.cancel()
        coordinator = nil
        lifecycleObservers.removeAll()
        kernel.unregisterProvider((any AgentLoopRetryLifecycleProviding).self)
    }

    // MARK: - AgentLoopRetryLifecycleProviding

    public func isRetrying(conversationID: UUID) -> Bool {
        coordinator?.isRetrying(conversationID: conversationID) ?? false
    }

    public func cancelRetry(for conversationID: UUID) {
        coordinator?.cancelRetry(for: conversationID)
    }

    public func addRetryLifecycleObserver(
        _ callback: @escaping (AgentLoopRetryLifecycleEvent) -> Void
    ) -> any AgentLoopRetryLifecycleObserverHandle {
        let id = UUID()
        lifecycleObservers[id] = callback
        return RetryLifecycleObserverHandle { [weak self] in
            self?.lifecycleObservers.removeValue(forKey: id)
        }
    }

    private func publishLifecycleEvent(_ event: AgentLoopRetryLifecycleEvent) {
        for observer in lifecycleObservers.values {
            observer(event)
        }
    }
}

/// 用闭包实现生命周期观察句柄，避免把插件内部字典暴露给消费方。
@MainActor
private final class RetryLifecycleObserverHandle: AgentLoopRetryLifecycleObserverHandle {
    private let onCancel: () -> Void

    init(_ onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}
