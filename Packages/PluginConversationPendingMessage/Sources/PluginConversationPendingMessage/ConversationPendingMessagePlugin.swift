import os
import Foundation
import KernelCore
import KitSuperLog
import ProviderChatSection
import ProviderConversation
import ProviderMessageSender
import SwiftUI

/// 待发消息插件：显示当前会话中排在活跃回合之后的待发消息队列。
///
/// - 在 Chat 分区 bottom-fixed 位置（输入区上方）注册待发消息列表；
/// - 显示每条待发消息的文本 + 附件数量，支持单独取消；
/// - 数据来自 `MessageSendingProviding.pendingMessages(for:)`。
@MainActor
public final class ConversationPendingMessagePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-pending-message", category: "ConversationPendingMessage")

    public let id = "com.coffic.lumi.plugin.conversation-pending-message"
    public let order = 82
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-pending-message",
        name: "Conversation Pending Message",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}
    private var viewModel: PendingMessageViewModel?
    private var observer: PendingMessageObserver?
    private var messageCapability: PendingMessageSendingCapability?
    private var conversationCapability: PendingMessageConversationCapability?

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let sender = kernel.resolveProvider((any MessageSendingProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding or MessageSendingProviding from kernel")
            return
        }

        guard let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ConversationManaging from kernel")
            return
        }

        let messageCapability = PendingMessageSendingCapabilityAdapter(sender: sender)
        let conversationCapability = PendingMessageConversationCapabilityAdapter(conversations: conversations)
        let viewModel = PendingMessageViewModel(capability: messageCapability)
        self.messageCapability = messageCapability
        self.conversationCapability = conversationCapability
        self.viewModel = viewModel
        chat.addItems([
            ChatSectionItem(
                id: "\(id).pending-list",
                order: 82,
                placement: .bottomFixed,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                PendingMessageListView(viewModel: viewModel)
            },
        ])
    }

    public func onReady(kernel: KernelCoreContainer) throws {
        guard let viewModel,
              let messageCapability,
              let conversationCapability else {
            Self.logger.error("\(Self.t)Failed to initialize PendingMessageObserver: required providers unavailable")
            return
        }

        observer?.cancel()
        observer = PendingMessageObserver(
            messageCapability: messageCapability,
            conversationCapability: conversationCapability,
            viewModel: viewModel
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        observer?.cancel()
        observer = nil
        messageCapability = nil
        conversationCapability = nil
        viewModel = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: "\(id).pending-list")
    }
}
