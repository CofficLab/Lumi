import Foundation

public enum AgentMessageNotification {
    public static let conversationIDKey = "conversationId"
}

public enum AgentTurnPhaseNotification {
    public static let phaseKey = "phase"
}

public extension Notification.Name {
    /// Agent 管线：消息已写入持久化存储。
    static let messageSaved = Notification.Name("agent.messageSaved")
    /// Agent 管线：会话 turn phase 变化；`object` 为 conversationID。
    static let agentTurnPhaseChanged = Notification.Name("agent.turnPhaseChanged")
}

@MainActor
public enum AgentTurnLifecycle {
    public static func postMessageSaved(conversationID: UUID) {
        NotificationCenter.default.post(
            name: .messageSaved,
            object: nil,
            userInfo: [AgentMessageNotification.conversationIDKey: conversationID]
        )
    }

    public static func postPhaseChanged(_ phase: AgentTurnPhase, conversationID: UUID) {
        NotificationCenter.default.post(
            name: .agentTurnPhaseChanged,
            object: conversationID,
            userInfo: [AgentTurnPhaseNotification.phaseKey: phase.rawValue]
        )
    }

    /// 将 Agent 管线 turn 结束原因广播为 `lumiTurnFinished`（及成功时的 `lumiTurnCompleted`）。
    public static func postTurnFinished(conversationID: UUID, reason: TurnEndReason) {
        let lumiReason = LumiTurnEndReason(reason)
        let userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiTurnFinishedNotification.reasonKey: lumiReason.rawValue,
        ]
        NotificationCenter.default.post(
            name: .lumiTurnFinished,
            object: nil,
            userInfo: userInfo
        )
        if lumiReason == .completed {
            NotificationCenter.default.post(
                name: .lumiTurnCompleted,
                object: nil,
                userInfo: userInfo
            )
        }
    }
}
