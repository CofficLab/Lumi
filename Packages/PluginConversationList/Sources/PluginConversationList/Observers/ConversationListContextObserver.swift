import Combine
import Foundation
import ProviderConversation
import ProviderConversationState

/// Keeps the list context synchronized with conversation and state providers.
@MainActor
final class ConversationListContextObserver {
    private var selectedConversationHandle: (any SelectedConversationObserverHandle)?
    private var stateCancellable: AnyCancellable?

    init(
        conversations: any ConversationManaging,
        conversationState: (any ConversationStateProviding)?,
        context: ConversationListContext
    ) {
        selectedConversationHandle = conversations.addSelectedConversationObserver { [weak context] newID in
            context?.selectedConversationID = newID
        }
        stateCancellable = conversationState?.objectWillChange.sink { [weak context] _ in
            context?.objectWillChange.send()
        }
    }

    func cancel() {
        selectedConversationHandle?.cancel()
        selectedConversationHandle = nil
        stateCancellable?.cancel()
        stateCancellable = nil
    }
}
