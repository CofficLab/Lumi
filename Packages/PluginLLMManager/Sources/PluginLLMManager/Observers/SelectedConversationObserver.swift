import Foundation
import ProviderConversation

/// Forwards selected-conversation changes to the LLM manager plugin.
@MainActor
final class SelectedConversationObserver {
    private var handle: (any SelectedConversationObserverHandle)?

    init(conversations: any ConversationManaging, onChange: @escaping (UUID?) -> Void) {
        handle = conversations.addSelectedConversationObserver { conversationID in
            onChange(conversationID)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
