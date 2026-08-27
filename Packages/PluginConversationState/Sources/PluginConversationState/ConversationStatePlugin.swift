import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderConversationState
import ProviderToolManager

/// 将会话状态维护能力接入内核。
///
/// 状态逻辑由 `DefaultConversationStateProvider` 负责；插件只负责在所有
/// AgentLoop/ToolManager 替换完成后完成依赖解析、监听建立和 Provider 注册。
@MainActor
public final class ConversationStatePlugin: SuperPlugin {
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
        guard let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self),
              let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            return
        }
        let provider = DefaultConversationStateProvider(agentLoop: agentLoop, toolManager: toolManager)
        kernel.unregisterProvider((any ConversationStateProviding).self)
        try kernel.registerProvider((any ConversationStateProviding).self, provider)
    }
}
