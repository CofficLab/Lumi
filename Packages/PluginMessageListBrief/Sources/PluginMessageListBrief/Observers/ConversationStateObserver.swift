import ProviderConversationState

/// 将会话活动状态变化转发给消息列表 ViewModel。
@MainActor
final class ConversationStateObserver {
    private var handle: (any ConversationStateObserverHandle)?

    init(state: any ConversationStateProviding, viewModel: ListV1ViewModel) {
        handle = state.addConversationStateObserver { [weak viewModel] change in
            viewModel?.handleConversationStateChange(change)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
