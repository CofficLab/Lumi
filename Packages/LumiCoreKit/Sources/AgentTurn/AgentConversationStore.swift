import Foundation

@MainActor
public protocol AgentConversationStore: AnyObject {
    func loadMessages(for conversationID: UUID) -> [AgentChatMessage]
    func loadTurnPhase(for conversationID: UUID) -> AgentTurnPhase
    func saveMessage(_ message: AgentChatMessage, conversationId: UUID)
}

@MainActor
public final class UnavailableAgentConversationStore: AgentConversationStore {
    public init() {}

    public func loadMessages(for conversationID: UUID) -> [AgentChatMessage] { [] }

    public func loadTurnPhase(for conversationID: UUID) -> AgentTurnPhase { .idle }

    public func saveMessage(_ message: AgentChatMessage, conversationId: UUID) {}
}
