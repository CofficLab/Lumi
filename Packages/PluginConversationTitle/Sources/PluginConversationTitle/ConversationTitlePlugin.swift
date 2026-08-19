import os
import Foundation
import KernelCore
import SuperLogKit
import ProviderConversation
import ProviderMessage
import ProviderLLMManager
import ProviderToolManager
import AgentToolKit

/// 对话标题插件：自动生成标题 + 标题更新 Agent 工具。
///
/// 复刻自旧版 `Plugins/ConversationTitlePlugin`：
/// - 自动标题：监听回合事件总线的 `lumiMessageSaved`（新架构已桥接），
///   对每条新会话的第一条用户消息用 LLM 生成简短标题并写入；
/// - Agent 工具：注册 `update_conversation_title`，让 LLM 可主动改标题。
@MainActor
public final class ConversationTitlePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-title", category: "ConversationTitle")

    /// 保持旧版插件 ID。
    public let id = "com.coffic.lumi.plugin.conversation-title"
    public let order = 77
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-title",
        name: "Conversation Title",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    private var autoTitleService: AutoConversationTitleService?

    public init() {}


    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self),
              let llmProvider = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ConversationManaging, MessageManaging, LLMManaging from kernel")
            return
        }

        autoTitleService = AutoConversationTitleService(
            kernel: kernel,
            conversations: conversations,
            messages: messages,
            llmProvider: llmProvider
        )

        // 注册标题更新 Agent 工具。
        kernel.resolveProvider((any ToolManagerProviding).self)?.add(
            ConversationTitleUpdateTool(conversations: conversations),
            pluginID: id
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        autoTitleService?.stop()
        autoTitleService = nil
        kernel.resolveProvider((any ToolManagerProviding).self)?
            .remove(id: ConversationTitleUpdateTool.toolName)
    }
}
