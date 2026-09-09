import ProviderConversation

/// 将当前会话切换转发给消息列表 ViewModel。
@MainActor
final class SelectedConversationObserver {
    private var handle: (any SelectedConversationObserverHandle)?

    init(conversations: any ConversationManaging, viewModel: ListV1ViewModel) {
        handle = conversations.addSelectedConversationObserver { [weak viewModel] conversationID in
            viewModel?.handleSelectedConversationChange(conversationID)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
