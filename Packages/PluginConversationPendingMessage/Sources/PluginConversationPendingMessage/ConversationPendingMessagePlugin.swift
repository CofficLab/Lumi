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
/// 复刻自旧版 `Plugins/ConversationPendingMessagePlugin`：
/// - 在 Chat 分区 bottom-fixed 位置（输入区上方）注册待发消息列表；
/// - 显示每条待发消息的文本 + 附件数量，支持单独取消；
/// - 数据来自 `MessageSendingProviding.pendingMessages(for:)`（队列能力
///   已在新版 `DefaultMessageSendingProviding` 实现）。
@MainActor
public final class ConversationPendingMessagePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-pending-message", category: "ConversationPendingMessage")

    /// 保持旧版插件 ID。
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
    private var sendingBox: MessageSendingBox? = nil
    private var selectionBox: ConversationSelectionBox? = nil

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let sender = kernel.resolveProvider((any MessageSendingProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding, ConversationManaging, MessageSendingProviding from kernel")
            return
        }

        let box = MessageSendingBox(sender: sender)
        let selectionBox = ConversationSelectionBox(conversations: conversations)
        sendingBox = box
        self.selectionBox = selectionBox
        chat.addItems([
            ChatSectionItem(
                id: "\(id).pending-list",
                order: 82,
                placement: .bottomFixed,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                PendingMessageListView(box: box, selection: selectionBox)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        sendingBox?.cancel()
        sendingBox = nil
        selectionBox?.cancel()
        selectionBox = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: "\(id).pending-list")
    }
}


