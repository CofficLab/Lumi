import ProviderConversation

/// 将当前会话切换转发给消息列表 ViewModel。
@MainActor
final class SelectedConversationObserver {
    private var handle: (any SelectedConversationObserverHandle)?

    init(
        conversations: any ConversationManaging,
        viewModel: ListV1ViewModel,
        conversationStateViewModel: ConversationStateViewModel,
        conversationStateObserver: ConversationStateObserver?
    ) {
        if let conversationStateObserver {
            conversationStateObserver.updateSelectedConversation(conversations.selectedConversationID)
        } else {
            conversationStateViewModel.updateSelectedConversation(conversations.selectedConversationID)
        }
        handle = conversations.addSelectedConversationObserver {
            [weak viewModel, weak conversationStateViewModel, weak conversationStateObserver] conversationID in
            viewModel?.handleSelectedConversationChange(conversationID)
            if let conversationStateObserver {
                conversationStateObserver.updateSelectedConversation(conversationID)
            } else {
                conversationStateViewModel?.updateSelectedConversation(conversationID)
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
