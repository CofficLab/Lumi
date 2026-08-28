import Foundation
import KitSuperLog
import os
import ProviderConversation
import ProviderMessage

/// 监听选中会话变化，并为速度 ViewModel 提供当前会话的消息快照。
@MainActor
final class SpeedConversationObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-speed",
        category: "SpeedConversationObserver"
    )

    private let conversations: any ConversationManaging
    private let messages: any MessageManaging
    private let viewModel: ConversationSpeedViewModel
    private var observer: (any SelectedConversationObserverHandle)?

    init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        viewModel: ConversationSpeedViewModel
    ) {
        self.conversations = conversations
        self.messages = messages
        self.viewModel = viewModel

        refresh()
        observer = conversations.addSelectedConversationObserver { [weak self] conversationID in
            self?.selectedConversationDidChange(to: conversationID)
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }

    private func selectedConversationDidChange(to conversationID: UUID?) {
        if conversationID == nil {
            viewModel.selectConversation(nil, messages: [])
            return
        }
        refresh(conversationID: conversationID)
    }

    private func refresh() {
        refresh(conversationID: conversations.selectedConversationID)
    }

    private func refresh(conversationID: UUID?) {
        guard let conversationID else {
            viewModel.selectConversation(nil, messages: [])
            return
        }

        var snapshot = messages.messages(for: conversationID)
        if snapshot.isEmpty, let lastMessage = messages.lastMessage(in: conversationID) {
            snapshot = [lastMessage]
        }
        viewModel.selectConversation(conversationID, messages: snapshot)
    }
}
