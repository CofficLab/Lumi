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
    private var inputObserver: (any ConversationInputProvidingObserverHandle)?
    private var senderObserver: (any MessageSenderObserverHandle)?

    init(
        input: (any ConversationInputProviding)?,
        sender: (any MessageSendingProviding)?,
        state: ConversationInputViewState
    ) {
        state.refresh(errorMessage: input?.errorMessage)
        textHandle = input?.addTextObserver { [weak state] _ in
            state?.refresh()
        }
        inputObserver = input?.addObserver { [weak state] event in
            guard case let .errorMessageChanged(errorMessage) = event else { return }
            state?.refresh(errorMessage: errorMessage)
        }
        senderObserver = sender?.addMessageSenderObserver { [weak state] event in
            switch event {
            case .attachmentsChanged:
                state?.refresh()
            case .started, .turnCompleted, .turnFailed, .pendingMessagesChanged:
                break
            }
        }
    }

    func cancel() {
        textHandle?.cancel()
        textHandle = nil
        inputObserver = nil
        senderObserver = nil
    }
}
