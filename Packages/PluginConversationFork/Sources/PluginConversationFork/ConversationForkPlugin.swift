import os
import Foundation
import KernelCore
import KitSuperLog
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import ProviderLLMManager
import SwiftUI

/// 对话分叉插件：一键把当前对话摘要后续接到新对话。
///
/// 复刻自旧版 `Plugins/ConversationForkPlugin`：
/// - 在 Chat 分区 Action Bar 注册「续接到新对话」按钮；
/// - 点击后用当前模型生成历史摘要（失败回退为本地精简摘要），
///   创建新对话并把摘要作为首条 user 消息注入，自动开始续写。
@MainActor
public final class ConversationForkPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-fork", category: "ConversationFork")

    /// 保持旧版插件 ID。
    public let id = "com.coffic.lumi.plugin.conversation-fork"
    public let order = 80
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-fork",
        name: "Conversation Fork",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}


    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self),
              let sender = kernel.resolveProvider((any MessageSendingProviding).self),
              let llmProvider = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding, ConversationManaging, MessageManaging, MessageSendingProviding, LLMManaging from kernel")
            return
        }

        let summarizer = ConversationSummarizer(
            conversations: conversations,
            messages: messages,
            llmProvider: llmProvider
        )

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).action-bar-button",
                order: 80,
                placement: .actionTrailing
            ) {
                ConversationForkButton(
                    conversations: conversations,
                    messages: messages,
                    sender: sender,
                    summarizer: summarizer
                )
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).action-bar-button")
    }
}
