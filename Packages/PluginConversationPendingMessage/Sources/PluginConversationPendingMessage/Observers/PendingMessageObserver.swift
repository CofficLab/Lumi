import Foundation
import os
import ProviderConversation
import ProviderMessageSender

/// 把发送器和会话选择的外部变化同步到插件自己的 ViewModel。
@MainActor
final class PendingMessageObserver {
    private static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-pending-message",
        category: "PendingMessageObserver"
    )

    private let sender: any MessageSendingProviding
    private weak var viewModel: PendingMessageViewModel?
    private var senderObserver: (any MessageSenderObserverHandle)?
    private var conversationObserver: (any SelectedConversationObserverHandle)?

    init(
        conversations: any ConversationManaging,
        sender: any MessageSendingProviding,
        viewModel: PendingMessageViewModel
    ) {
        self.sender = sender
        self.viewModel = viewModel

        viewModel.selectConversation(
            conversations.selectedConversationID,
            pendingMessages: Self.pendingMessages(
                for: conversations.selectedConversationID,
                sender: sender
            )
        )

        senderObserver = sender.addMessageSenderObserver { [weak self] event in
            self?.handle(senderEvent: event)
        }
        conversationObserver = conversations.addSelectedConversationObserver { [weak self] conversationID in
            self?.handleSelectedConversationChange(conversationID)
        }

        let selectedConversation = conversations.selectedConversationID?.uuidString.prefix(8) ?? "nil"
        Self.logger.info("observer initialized: selectedConversation=\(selectedConversation)")
    }

    func cancel() {
        senderObserver?.cancel()
        senderObserver = nil
        conversationObserver?.cancel()
        conversationObserver = nil
        viewModel = nil
    }

    private func handle(senderEvent: MessageSenderEvent) {
        guard case let .pendingMessagesChanged(conversationID) = senderEvent else { return }
        let messages = sender.pendingMessages(for: conversationID)
        Self.logger.info("pending event -> viewModel: conversation=\(conversationID.uuidString.prefix(8)), count=\(messages.count)")
        viewModel?.updatePendingMessages(for: conversationID, pendingMessages: messages)
    }

    private func handleSelectedConversationChange(_ conversationID: UUID?) {
        let messages = Self.pendingMessages(for: conversationID, sender: sender)
        let selectedConversation = conversationID?.uuidString.prefix(8) ?? "nil"
        Self.logger.info("conversation changed -> viewModel: conversation=\(selectedConversation), count=\(messages.count)")
        viewModel?.selectConversation(conversationID, pendingMessages: messages)
    }

    private static func pendingMessages(
        for conversationID: UUID?,
        sender: any MessageSendingProviding
    ) -> [PendingChatMessage] {
        guard let conversationID else { return [] }
        return sender.pendingMessages(for: conversationID)
    }
}
