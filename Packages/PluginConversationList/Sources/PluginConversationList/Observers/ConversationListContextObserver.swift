import Foundation
import ProviderConversation
import ProviderConversationState

/// Keeps the list context synchronized with conversation and state providers.
@MainActor
final class ConversationListContextObserver {
    private var selectedConversationHandle: (any SelectedConversationObserverHandle)?
    private var conversationHandle: (any ConversationObserverHandle)?
    private var stateHandle: (any ConversationStateObserverHandle)?

    init(
        conversations: any ConversationManaging,
        conversationState: (any ConversationStateProviding)?,
        context: ConversationListContext
    ) {
        selectedConversationHandle = conversations.addSelectedConversationObserver { [weak context] newID in
            context?.selectedConversationID = newID
        }
        conversationHandle = conversations.addConversationObserver { [weak context] event in
            switch event {
            case .selected:
                break
            default:
                context?.markConversationsChanged()
            }
        }
        stateHandle = conversationState?.addConversationStateObserver { [weak context] _ in
            context?.markConversationsChanged()
        }
    }

    func cancel() {
        selectedConversationHandle?.cancel()
        selectedConversationHandle = nil
        conversationHandle?.cancel()
        conversationHandle = nil
        stateHandle?.cancel()
        stateHandle = nil
    }
}
