import Combine
import Foundation
import ProviderConversationState
import ProviderMessage
import ProviderMessageStreaming

/// Owns the external Provider subscriptions used by message-list view models.
@MainActor
final class MessageListServicesObserver {
    private var messageChangeObserver: (any MessageChangeObserverHandle)?
    private var cancellables = Set<AnyCancellable>()
    private var didBindConversationState = false
    private var didBindStreaming = false

    func bindMessages(
        _ messages: any MessageManaging,
        onChange: ((MessageChange) -> Void)?,
        onWillChange: @escaping () -> Void
    ) {
        guard messageChangeObserver == nil else { return }
        if let onChange {
            messageChangeObserver = messages.addMessageChangeObserver(onChange)
        }
        messages.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: onWillChange)
            .store(in: &cancellables)
    }

    func bindConversationState(
        _ state: any ConversationStateProviding,
        onWillChange: @escaping () -> Void
    ) {
        guard !didBindConversationState else { return }
        state.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: onWillChange)
            .store(in: &cancellables)
        didBindConversationState = true
    }

    func bindStreaming(
        _ streaming: any MessageStreamingProviding,
        onWillChange: @escaping () -> Void
    ) {
        guard !didBindStreaming else { return }
        streaming.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: onWillChange)
            .store(in: &cancellables)
        didBindStreaming = true
    }

    func cancel() {
        messageChangeObserver?.cancel()
        messageChangeObserver = nil
        cancellables.removeAll()
        didBindConversationState = false
        didBindStreaming = false
    }
}
