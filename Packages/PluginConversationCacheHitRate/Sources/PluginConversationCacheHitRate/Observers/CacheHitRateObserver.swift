import Foundation
import ProviderConversation
import ProviderMessage

/// Observes conversation and message changes for the cache-hit toolbar.
@MainActor
final class CacheHitRateObserver {
    private var conversationHandle: (any SelectedConversationObserverHandle)?
    private var messageHandle: (any MessageInsertedObserverHandle)?

    init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        onConversationChange: @escaping (UUID?) -> Void,
        onMessageInsert: @escaping (UUID) -> Void
    ) {
        onConversationChange(conversations.selectedConversationID)
        conversationHandle = conversations.addSelectedConversationObserver { newID in
            onConversationChange(newID)
        }
        messageHandle = messages.addMessageInsertedObserver { _, conversationID in
            onMessageInsert(conversationID)
        }
    }

    func cancel() {
        conversationHandle?.cancel()
        conversationHandle = nil
        messageHandle?.cancel()
        messageHandle = nil
    }
}
