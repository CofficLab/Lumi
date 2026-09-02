import Foundation
import ProviderAgentLoop
import ProviderConversation

/// Observes the selected conversation for the agent-turn status toolbar.
@MainActor
final class AgentTurnStatusObserver {
    private var handle: (any SelectedConversationObserverHandle)?

    init(
        conversations: any ConversationManaging,
        onConversationChange: @escaping (UUID?) -> Void
    ) {
        onConversationChange(conversations.selectedConversationID)
        handle = conversations.addSelectedConversationObserver { newID in
            onConversationChange(newID)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
