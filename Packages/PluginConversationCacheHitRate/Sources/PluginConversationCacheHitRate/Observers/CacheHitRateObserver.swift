import Foundation
import ProviderConversation
import ProviderMessage

/// Observes conversation and message changes for the cache-hit toolbar.
@MainActor
final class CacheHitRateObserver {
    private var conversationHandle: (any SelectedConversationObserverHandle)?
    private var messageChangeHandle: (any MessageChangeObserverHandle)?

    init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        onConversationChange: @escaping (UUID?) -> Void,
        onMessageChange: @escaping (UUID) -> Void
    ) {
        onConversationChange(conversations.selectedConversationID)
        conversationHandle = conversations.addSelectedConversationObserver { newID in
            onConversationChange(newID)
        }
        messageChangeHandle = messages.addMessageChangeObserver { change in
            switch change {
            case let .inserted(_, conversationID),
                 let .persisted(_, conversationID),
                 let .updated(conversationID),
                 let .deleted(_, conversationID),
                 let .cleared(conversationID):
                onMessageChange(conversationID)
            }
        }
    }

    func cancel() {
        conversationHandle?.cancel()
        conversationHandle = nil
        messageChangeHandle?.cancel()
        messageChangeHandle = nil
    }
}
