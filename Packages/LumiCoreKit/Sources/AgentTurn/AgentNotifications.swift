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

    /// - Note: turn 结束通知（`.lumiTurnFinished` / `.lumiTurnCompleted`）已统一由
    ///   `LumiChatKit.SendPipeline` **唯一发送**（参见阶段 0 重构）。
    ///   本函数保留签名，仅为兼容 `SuperPluginLegacyTypes.finishAgentTurn` 的默认闭包调用；
    ///   此处不再 post，避免同一通知被 CoreKit 与 ChatKit 双重发送。
    public static func postTurnFinished(conversationID: UUID, reason: TurnEndReason) {
        // 故意留空：turn 结束通知的唯一发送方是 LumiChatKit.SendPipeline。
        // 详见 `docs/architecture-refactor-proposal.md` §5 阶段 0。
        _ = conversationID
        _ = reason
    }
}
