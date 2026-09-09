import ProviderMessageStreaming

/// 将流式状态变化转发给消息列表 ViewModel。
@MainActor
final class StreamingObserver {
    private var handle: (any MessageStreamingObserverHandle)?

    init(streaming: any MessageStreamingProviding, viewModel: ListV1ViewModel) {
        handle = streaming.addMessageStreamingObserver { [weak viewModel] change in
            viewModel?.handleStreamingChange(change)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
