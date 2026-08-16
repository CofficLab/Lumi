import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage

@MainActor
public final class DefaultMessageSendingProviding: MessageSendingProviding {
    private let conversations: any ConversationManaging
    private let messages: any MessageManaging
    private let agentLoop: any AgentLoopProviding
    private var currentTask: Task<Void, Never>?

    @Published public private(set) var isSending = false

    public init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: any AgentLoopProviding
    ) {
        self.conversations = conversations
        self.messages = messages
        self.agentLoop = agentLoop
    }

    public func sendMessage(_ content: String, conversationID: UUID? = nil) async throws {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let targetID: UUID
        if let conversationID {
            targetID = conversationID
        } else if let selected = conversations.selectedConversationID {
            targetID = selected
        } else {
            targetID = try conversations.createConversation(
                title: nil,
                projectPath: nil,
                providerID: nil,
                modelName: nil
            )
        }
        // A newly-created conversation must become the active timeline before
        // the message list renders; otherwise the user message is persisted
        // into an invisible, unselected conversation.
        if conversations.selectedConversationID != targetID {
            conversations.selectConversation(id: targetID)
        }

        let userMessage = Message(conversationID: targetID, role: .user, content: trimmed)
        messages.insertMessage(userMessage, to: targetID)
        isSending = true

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isSending = false }
            _ = try? await agentLoop.runTurn(in: targetID)
        }
        currentTask = task
        await task.value
        currentTask = nil
    }

    public func cancelCurrentRequest() {
        currentTask?.cancel()
        if let conversationID = conversations.selectedConversationID {
            agentLoop.cancelTurn(in: conversationID)
        }
        isSending = false
    }
}
