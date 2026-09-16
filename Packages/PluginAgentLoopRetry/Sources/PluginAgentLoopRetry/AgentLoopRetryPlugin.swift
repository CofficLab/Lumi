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
