import Foundation
import ProviderConversation
import ProviderLLMManager
import ProviderMessage

/// Observes conversation, message, and LLM-provider changes for context size.
@MainActor
final class ContextSizeObserver {
    private var conversationHandle: (any SelectedConversationObserverHandle)?
    private var messageHandle: (any MessageInsertedObserverHandle)?
    private var llmHandle: (any LLMManagerObserverHandle)?

    init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        llmManager: any LLMManaging,
        onConversationChange: @escaping (UUID?) -> Void,
        onMessageInsert: @escaping (UUID) -> Void,
        onLLMChange: @escaping () -> Void
    ) {
        onConversationChange(conversations.selectedConversationID)
        conversationHandle = conversations.addSelectedConversationObserver { newID in
            onConversationChange(newID)
        }
        messageHandle = messages.addMessageInsertedObserver { _, conversationID in
            onMessageInsert(conversationID)
        }
        llmHandle = llmManager.addObserver { _ in
            onLLMChange()
        }
    }

    func cancel() {
        conversationHandle?.cancel()
        conversationHandle = nil
        messageHandle?.cancel()
        messageHandle = nil
        llmHandle?.cancel()
        llmHandle = nil
    }
}
