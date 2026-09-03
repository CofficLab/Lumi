import Combine
import Foundation
import ProviderConversationInput
import ProviderMessageSender

/// Plugin-owned state used by the input views.
@MainActor
final class ConversationInputViewState: ObservableObject {
    @Published private(set) var revision = 0
    @Published private(set) var errorMessage: String?

    func refresh() {
        revision &+= 1
    }

    func refresh(errorMessage: String?) {
        self.errorMessage = errorMessage
        revision &+= 1
    }
}

/// Bridges input and attachment provider changes into the plugin-owned view state.
@MainActor
final class ConversationInputObserver {
    private var textHandle: (any TextInputObserverHandle)?
    private var inputCancellable: AnyCancellable?
    private var senderCancellable: AnyCancellable?

    init(
        input: (any ConversationInputProviding)?,
        sender: (any MessageSendingProviding)?,
        state: ConversationInputViewState
    ) {
        state.refresh(errorMessage: input?.errorMessage)
        textHandle = input?.addTextObserver { [weak state] _ in
            state?.refresh()
        }
        inputCancellable = input?.objectWillChange.sink { [weak input, weak state] _ in
            Task { @MainActor in
                await Task.yield()
                guard !Task.isCancelled else { return }
                state?.refresh(errorMessage: input?.errorMessage)
            }
        }
        senderCancellable = sender?.objectWillChange.sink { [weak state] _ in
            state?.refresh()
        }
    }

    func cancel() {
        textHandle?.cancel()
        textHandle = nil
        inputCancellable = nil
        senderCancellable = nil
    }
}
