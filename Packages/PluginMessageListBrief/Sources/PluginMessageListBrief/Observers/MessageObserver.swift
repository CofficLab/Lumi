import ProviderMessage

/// 将消息变化转发给当前对话消息列表 VM。
@MainActor
final class MessageObserver {
    private var handle: (any MessageChangeObserverHandle)?

    init(messages: any MessageManaging, vm: ConversationMessageListVM) {
        handle = messages.addMessageChangeObserver { [weak vm] change in
            vm?.handleMessageChange(change)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
