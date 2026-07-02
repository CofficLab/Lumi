import Foundation

/// 在 `saveMessage` 后自动广播 `messageSaved`，供 Agent 插件链使用。
@MainActor
public final class NotifyingAgentConversationStore: AgentConversationStore {
    private let base: any AgentConversationStore

    public init(base: any AgentConversationStore) {
        self.base = base
    }

    public func loadMessages(for conversationID: UUID) -> [AgentChatMessage] {
        base.loadMessages(for: conversationID)
    }

    public func loadTurnPhase(for conversationID: UUID) -> AgentTurnPhase {
        base.loadTurnPhase(for: conversationID)
    }

    public func saveMessage(_ message: AgentChatMessage, conversationId: UUID) {
        base.saveMessage(message, conversationId: conversationId)
        AgentTurnLifecycle.postMessageSaved(conversationID: conversationId)
    }
}
