import Foundation
import ProviderConversation
import ProviderConversationState

/// Observes selected-conversation and conversation-state changes for the send bar.
@MainActor
final class SendActionBarConversationObserver {
    private var stateHandle: (any ConversationStateObserverHandle)?
    private var conversationHandle: (any SelectedConversationObserverHandle)?

    init(
        conversations: any ConversationManaging,
        conversationState: any ConversationStateProviding,
        onChange: @escaping () -> Void
    ) {
        stateHandle = conversationState.addConversationStateObserver { _ in
            onChange()
        }
        conversationHandle = conversations.addSelectedConversationObserver { _ in
            onChange()
        }
    }

    func cancel() {
        stateHandle?.cancel()
        stateHandle = nil
        conversationHandle?.cancel()
        conversationHandle = nil
    }
}
