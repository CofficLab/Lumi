import Foundation

/// Agent 会话持久化能力。
///
/// 供 MessageSender 等 Agent 管线插件读写消息与 Turn 阶段，
/// 由 App 层桥接 `ChatHistoryService` 与 `ConversationService` 注入实现。
@MainActor
public protocol AgentConversationStore: Sendable {
    /// 加载会话全部消息。
    func loadMessages(for conversationId: UUID) -> [ChatMessage]

    /// 保存消息到数据库。
    func saveMessage(_ message: ChatMessage, conversationId: UUID)

    /// 读取 Agent Turn 阶段。
    func loadTurnPhase(for conversationId: UUID) -> AgentTurnPhase

    /// 设置 Agent Turn 阶段。
    func setTurnPhase(_ phase: AgentTurnPhase, conversationId: UUID)
}

/// 未注入实现时的空操作占位。
public struct UnavailableAgentConversationStore: AgentConversationStore {
    public init() {}

    public func loadMessages(for conversationId: UUID) -> [ChatMessage] { [] }

    public func saveMessage(_ message: ChatMessage, conversationId: UUID) {}

    public func loadTurnPhase(for conversationId: UUID) -> AgentTurnPhase { .idle }

    public func setTurnPhase(_ phase: AgentTurnPhase, conversationId: UUID) {}
}
