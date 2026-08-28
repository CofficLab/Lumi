import Foundation
import KernelCore
import KitAgentTool
import KitSuperLog
import os
import ProviderChatSection
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderToolManager
import SwiftUI

/// 对话标题插件：自动生成标题 + 标题更新 Agent 工具。
///
/// - 自动标题：监听回合事件总线的 `lumiMessageSaved`（新架构已桥接），
///   对每条新会话的第一条用户消息用 LLM 生成简短标题并写入；
/// - Agent 工具：注册 `update_conversation_title`，让 LLM 可主动改标题。
@MainActor
public final class ConversationTitlePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-title", category: "ConversationTitle")

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

    private var autoTitleService: TitleService?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding from kernel while booting conversation title plugin")
            return
        }
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ConversationManaging from kernel while booting conversation title plugin")
            return
        }
        guard let messages = kernel.resolveProvider((any MessageManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve MessageManaging from kernel while booting conversation title plugin")
            return
        }
        guard let llmProvider = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve LLMManaging from kernel while booting conversation title plugin")
            return
        }

        autoTitleService = TitleService(
            kernel: kernel,
            conversations: conversations,
            messages: messages,
            llmProvider: llmProvider
        )

        // 注册标题更新 Agent 工具。
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            toolManager.add(
                TitleUpdateTool(conversations: conversations),
                pluginID: id
            )
        } else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding while registering conversation title tool")
        }

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).header",
                order: 0,
                placement: .header
            ) {
                HeaderView(conversations: conversations)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let chat = kernel.resolveProvider((any ChatSectionProviding).self) {
            chat.removeBarItem(id: "\(id).header")
        } else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding while removing conversation title header")
        }

        if let autoTitleService {
            autoTitleService.stop()
            self.autoTitleService = nil
        } else {
            Self.logger.error("\(Self.t)Failed to stop conversation title service because it is unavailable")
        }
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding while removing conversation title tool")
            return
        }
        toolManager.remove(id: TitleUpdateTool.toolName)
    }
}
