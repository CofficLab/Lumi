import Foundation
import ProviderMessage

/// 监听消息插入，并刷新当前选中会话的速度状态。
@MainActor
final class SpeedMessageObserver {
    private let messages: any MessageManaging
    private let viewModel: ConversationSpeedViewModel
    private var observer: (any MessageInsertedObserverHandle)?

    init(messages: any MessageManaging, viewModel: ConversationSpeedViewModel) {
        self.messages = messages
        self.viewModel = viewModel
        observer = messages.addMessageInsertedObserver { [weak self] _, conversationID in
            self?.messageDidInsert(in: conversationID)
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }

    private func messageDidInsert(in conversationID: UUID) {
        guard viewModel.selectedConversationID == conversationID else { return }

        var snapshot = messages.messages(for: conversationID)
        if snapshot.isEmpty, let lastMessage = messages.lastMessage(in: conversationID) {
            snapshot = [lastMessage]
        }
        viewModel.refresh(conversationID: conversationID, messages: snapshot)
    }
}
