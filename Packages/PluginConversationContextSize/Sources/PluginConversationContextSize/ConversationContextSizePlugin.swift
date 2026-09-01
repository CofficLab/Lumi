import os
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderLLMManager
import ProviderLLMVendors
import ProviderMessage
import KitSuperLog
import SwiftUI

/// 上下文窗口大小插件。
///
/// 在 Chat 工具栏显示当前模型的上下文窗口大小和最近一次请求的输入 token 数。
@MainActor
public final class ConversationContextSizePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-context-size",
        category: "ConversationContextSize"
    )

    public let id = "com.coffic.conversation-context-size"
    public let order = 85
    public let metadata = PluginMetadata(
        id: "com.coffic.conversation-context-size",
        name: "Conversation Context Size",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .required
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self),
              let llmManager = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve required providers")
            return
        }

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: order,
                placement: .toolbarLeading
            ) {
                ContextSizeToolbarView(
                    conversations: conversations,
                    messages: messages,
                    llmManager: llmManager
                )
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar-button")
    }
}
