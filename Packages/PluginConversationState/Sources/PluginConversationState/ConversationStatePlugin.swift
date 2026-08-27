import Foundation
import KernelCore
import KitSuperLog
import os
import ProviderAgentLoop
import ProviderConversationState
import ProviderToolManager
import ProviderMessageSender

/// 将会话状态维护能力接入内核。
///
/// 状态逻辑由 `DefaultConversationStateProvider` 负责；插件只负责在所有
/// AgentLoop/ToolManager 替换完成后完成依赖解析、监听建立和 Provider 注册。
@MainActor
public final class ConversationStatePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-state",
        category: "ConversationStatePlugin"
    )
    nonisolated public static let emoji = "🔄"

    private var agentLoopObserver: AgentLoopStateObserver?
    private var toolManagerObserver: ToolManagerStateObserver?
    private var senderObserver: MessageSenderStateObserver?

    public let id = "com.coffic.lumi.plugin.conversation-state"
    public let order = 10
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-state",
        name: "Conversation State",
        description: "Maintains conversation state from agent and tool events.",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self) else {
            Self.logger.error("\(Self.t)AgentLoopProviding not registered; cannot create ConversationStateProvider")
            return
        }
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)ToolManagerProviding not registered; cannot create ConversationStateProvider")
            return
        }
        guard let sender = kernel.resolveProvider((any MessageSendingProviding).self) else {
            Self.logger.error("\(Self.t)MessageSendingProviding not registered; cannot observe sending state")
            return
        }
        let provider = ConversationStateProvider()
        kernel.unregisterProvider((any ConversationStateProviding).self)
        try kernel.registerProvider((any ConversationStateProviding).self, provider)
        agentLoopObserver = AgentLoopStateObserver(agentLoop: agentLoop, provider: provider)
        toolManagerObserver = ToolManagerStateObserver(toolManager: toolManager, provider: provider)
        senderObserver = MessageSenderStateObserver(sender: sender, provider: provider)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        agentLoopObserver?.cancel()
        agentLoopObserver = nil
        toolManagerObserver?.cancel()
        toolManagerObserver = nil
        senderObserver?.cancel()
        senderObserver = nil
    }
}
