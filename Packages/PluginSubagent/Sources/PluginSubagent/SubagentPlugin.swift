import Foundation
import KernelCore
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderToolManager

/// 子代理委托插件（#1313）。
///
/// `onBoot` 把 `run_subagent` 工具注册进工具管理器；`onDisable` /
/// `onShutdown` 撤回。工具经 `SubagentConversationBridge` 创建隐藏子会话，
/// 在隔离回合里跑完任务后只把结论带回父上下文。
///
/// - Important: 与 FinderPlugin 相同，内核禁用插件时只撤回显式登记的贡献，
///   工具必须由本插件自己在 `onDisable` 里撤回，否则禁用后 LLM 仍能调用。
@MainActor
public final class SubagentPlugin: SuperPlugin {
    private static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.subagent",
        category: "Subagent"
    )

    public let id = "com.coffic.lumi.plugin.subagent"

    /// 必须晚于 PluginAgentLoop（order 8）：注册时要解析到真实的
    /// AgentLoopProviding，而不是默认降级实现。
    public let order = 9

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.subagent",
        name: "Subagent",
        description: "Delegate self-contained tasks to isolated subagent conversations and return only their conclusions.",
        category: .core,
        stage: .preview,
        policy: .alwaysOn
    )

    /// 让 onEnable 幂等：内核「曾 Boot 过再启用」只调 onEnable。
    private var isRegistered = false

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        registerContributions(kernel: kernel)
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        registerContributions(kernel: kernel)
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        unregisterContributions(kernel: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        unregisterContributions(kernel: kernel)
    }

    // MARK: - Contributions

    private func registerContributions(kernel: KernelCoreContainer) {
        guard !isRegistered else { return }

        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self),
              let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self)
        else {
            Self.logger.error("Subagent dependencies not found; run_subagent tool skipped")
            return
        }

        isRegistered = true
        toolManager.add(
            RunSubagentTool(
                conversations: conversations,
                messages: messages,
                agentLoop: agentLoop,
                toolManager: toolManager
            ),
            pluginID: id
        )
    }

    private func unregisterContributions(kernel: KernelCoreContainer) {
        guard isRegistered else { return }
        isRegistered = false
        kernel.resolveProvider((any ToolManagerProviding).self)?
            .remove(id: RunSubagentTool.toolName)
    }
}