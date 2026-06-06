import Foundation

public extension Notification.Name {
    /// 消息已保存到数据库
    static let messageSaved = Notification.Name("messageSaved")

    /// Agent Turn 阶段已变更；object: UUID (conversationId)
    static let agentTurnPhaseChanged = Notification.Name("agentTurnPhaseChanged")
}
