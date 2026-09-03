import Foundation
import ProviderAgentLoop
import ProviderConversation

/// Observes the selected conversation for the agent-turn status toolbar.
@MainActor
final class AgentTurnStatusObserver {
    private var handle: (any SelectedConversationObserverHandle)?

    init(
        conversations: any ConversationManaging,
        agentLoop: any AgentLoopProviding,
        onConversationChange: @escaping (UUID?) -> Void,
        onAgentLoopChange: @escaping (UUID) -> Void
    ) {
        onConversationChange(conversations.selectedConversationID)
        handle = conversations.addSelectedConversationObserver { newID in
            onConversationChange(newID)
        }
        agentLoopHandle = agentLoop.addAgentLoopObserver { event in
            switch event {
            case .started(let conversationID, _),
                 .toolCallsReceived(let conversationID, _, _, _),
                 .llmResponseReceived(let conversationID, _, _),
                 .suspended(let conversationID, _, _),
                 .completed(let conversationID, _),
                 .failed(let conversationID, _, _),
                 .cancelled(let conversationID, _):
                onAgentLoopChange(conversationID)
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
        agentLoopHandle?.cancel()
        agentLoopHandle = nil
    }

    private var agentLoopHandle: (any AgentLoopObserverHandle)?
}
