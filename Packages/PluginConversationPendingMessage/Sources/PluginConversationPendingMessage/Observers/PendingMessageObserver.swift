import Foundation
import os
import KitSuperLog
import ProviderMessageSender

/// 把插件 Capability 的外部变化同步到插件自己的 ViewModel。
@MainActor
final class PendingMessageObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.conversation-pending-message"
    )
    nonisolated static let emoji = "🐒"
    nonisolated static let verbose = false

    private let messageCapability: any PendingMessageSendingCapability
    private let conversationCapability: any PendingMessageConversationCapability
    private weak var viewModel: PendingMessageViewModel?
    private var senderObserver: (any PendingMessageSendingObserverHandle)?
    private var conversationObserver: (any PendingMessageConversationObserverHandle)?

    init(
        messageCapability: any PendingMessageSendingCapability,
        conversationCapability: any PendingMessageConversationCapability,
        viewModel: PendingMessageViewModel
    ) {
        self.messageCapability = messageCapability
        self.conversationCapability = conversationCapability
        self.viewModel = viewModel

        viewModel.selectConversation(
            conversationCapability.selectedConversationID,
            pendingMessages: Self.pendingMessages(
                for: conversationCapability.selectedConversationID,
                capability: messageCapability
            )
        )

        senderObserver = messageCapability.addObserver { [weak self] event in
            self?.handle(messageEvent: event)
        }
        conversationObserver = conversationCapability.addObserver { [weak self] conversationID in
            self?.handleSelectedConversationChange(conversationID)
        }

        let selectedConversation = conversationCapability.selectedConversationID?.uuidString.prefix(8) ?? "nil"
        if Self.verbose {
            Self.logger.info("\(Self.t)observer initialized: selectedConversation=\(selectedConversation)")
        }
    }

    func cancel() {
        senderObserver?.cancel()
        senderObserver = nil
        conversationObserver?.cancel()
        conversationObserver = nil
        viewModel = nil
    }

    private func handle(messageEvent: PendingMessageSendingEvent) {
        guard case let .pendingMessagesChanged(conversationID) = messageEvent else { return }
        let messages = messageCapability.pendingMessages(for: conversationID)
        if Self.verbose {
            Self.logger.info("\(Self.t)pending event -> viewModel: conversation=\(conversationID.uuidString.prefix(8)), count=\(messages.count)")
        }
        viewModel?.updatePendingMessages(for: conversationID, pendingMessages: messages)
    }

    private func handleSelectedConversationChange(_ conversationID: UUID?) {
        let messages = Self.pendingMessages(for: conversationID, capability: messageCapability)
        let selectedConversation = conversationID?.uuidString.prefix(8) ?? "nil"
        if Self.verbose {
            Self.logger.info("\(Self.t)conversation changed -> viewModel: conversation=\(selectedConversation), count=\(messages.count)")
        }
        viewModel?.selectConversation(conversationID, pendingMessages: messages)
    }

    private static func pendingMessages(
        for conversationID: UUID?,
        capability: any PendingMessageSendingCapability
    ) -> [PendingChatMessage] {
        guard let conversationID else { return [] }
        return capability.pendingMessages(for: conversationID)
    }
}
