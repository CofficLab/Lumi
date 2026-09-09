import ProviderMessage

/// 将消息变化转发给消息列表 ViewModel。
@MainActor
final class MessageObserver {
    private var handle: (any MessageChangeObserverHandle)?

    init(messages: any MessageManaging, viewModel: ListV1ViewModel) {
        handle = messages.addMessageChangeObserver { [weak viewModel] change in
            viewModel?.handleMessageChange(change)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
