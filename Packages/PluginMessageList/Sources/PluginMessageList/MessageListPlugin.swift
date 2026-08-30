import os
import KernelCore
import KitSuperLog
import LumiUI
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderConversationState
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderMessageStreaming
import ProviderPromptSuggestion
import ProviderProject
import ProviderToolbar
import ProviderToolManager
import SwiftUI

@MainActor
public final class MessageListPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-list", category: "MessageList")

    public let id = "com.coffic.lumi.plugin.message-list"
    public let order = 82

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.message-list",
        name: "消息列表",
        description: "会话消息时间线：brief/standard/detailed 三种展示模式（V1/V2/V3）",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding from kernel")
            return
        }
        let services = MessageListServices(
            conversations: kernel.resolveProvider((any ConversationManaging).self),
            conversationState: kernel.resolveProvider((any ConversationStateProviding).self),
            messages: kernel.resolveProvider((any MessageManaging).self),
            rendering: kernel.resolveProvider((any MessageRenderingProviding).self),
            sender: kernel.resolveProvider((any MessageSendingProviding).self),
            streaming: kernel.resolveProvider((any MessageStreamingProviding).self),
            toolManager: kernel.resolveProvider((any ToolManagerProviding).self),
            agentTurn: kernel.resolveProvider((any AgentLoopProviding).self),
            promptSuggestions: kernel.resolveProvider((any PromptSuggestionProviding).self),
            promptSuggestionExecutor: kernel.resolveProvider((any PromptSuggestionExecuting).self),
            project: kernel.resolveProvider((any ProjectProviding).self),
            toolbar: kernel.resolveProvider((any ToolbarProviding).self),
        )
        chat.addItems([ChatSectionItem(id: id, order: 100, fillsRemainingHeight: true) {
            ListView(services: services)
        }])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?.removeItem(id: id)
    }

}
