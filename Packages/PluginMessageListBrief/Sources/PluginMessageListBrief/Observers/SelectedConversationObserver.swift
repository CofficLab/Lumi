import ProviderConversation

/// 将当前会话切换转发给消息列表 VM。
@MainActor
final class SelectedConversationObserver {
    private var handle: (any SelectedConversationObserverHandle)?

    init(
        conversations: any ConversationManaging,
        vm: ConversationMessageListVM,
        stateVM: ConversationStateVM,
        conversationStateObserver: ConversationStateObserver?
    ) {
        if let conversationStateObserver {
            conversationStateObserver.updateSelectedConversation(conversations.selectedConversationID)
        } else {
            stateVM.updateSelectedConversation(conversations.selectedConversationID)
        }
        handle = conversations.addSelectedConversationObserver {
            [weak vm, weak stateVM, weak conversationStateObserver] conversationID in
            vm?.handleSelectedConversationChange(conversationID)
            if let conversationStateObserver {
                conversationStateObserver.updateSelectedConversation(conversationID)
            } else {
                stateVM?.updateSelectedConversation(conversationID)
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
