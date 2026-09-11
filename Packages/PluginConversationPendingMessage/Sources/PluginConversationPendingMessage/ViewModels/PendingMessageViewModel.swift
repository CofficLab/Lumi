import Combine
import Foundation
import ProviderMessageSender

/// 待发消息插件的展示状态。
///
/// ViewModel 只保存当前选中会话和待发消息快照；外部 Provider 的观察由
/// `PendingMessageObserver` 持有，避免 ViewModel 与 Provider observer 生命周期耦合。
@MainActor
final class PendingMessageViewModel: ObservableObject {
    @Published private(set) var selectedConversationID: UUID?
    @Published private(set) var pendingMessages: [PendingChatMessage] = []

    private let sender: any MessageSendingProviding

    init(sender: any MessageSendingProviding) {
        self.sender = sender
    }

    func selectConversation(
        _ conversationID: UUID?,
        pendingMessages: [PendingChatMessage]
    ) {
        selectedConversationID = conversationID
        self.pendingMessages = pendingMessages
    }

    func updatePendingMessages(
        for conversationID: UUID,
        pendingMessages: [PendingChatMessage]
    ) {
        guard selectedConversationID == conversationID else { return }
        self.pendingMessages = pendingMessages
    }

    func cancelPendingMessage(id: UUID) {
        guard let conversationID = selectedConversationID else { return }
        sender.cancelPendingMessage(id: id, in: conversationID)
    }
}
