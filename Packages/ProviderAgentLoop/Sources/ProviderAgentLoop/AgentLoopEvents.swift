import Foundation

/// 回合结束原因。
public enum AgentLoopEndReason: String, Sendable, Equatable {
    case completed
    case cancelled
    case failed
    case awaitingUserResponse
}

/// Agent 回合生命周期事件。
public enum AgentLoopEvent: Sendable {
    /// 回合开始。
    case turnStarted(conversationID: UUID, turnID: UUID)
    /// 一条消息落库（user / assistant / tool / status / error）。
    case messageSaved(conversationID: UUID, messageID: UUID, role: String)
    /// 回合正常完成。
    case turnCompleted(conversationID: UUID, turnID: UUID)
    /// 回合结束（任何原因，含 completed）。
    case turnFinished(conversationID: UUID, turnID: UUID?, reason: AgentLoopEndReason)
}

/// Agent 循环事件回调（宿主注入，把事件转发到事件总线 / 通知中心）。
public typealias AgentLoopEventHandler = @MainActor @Sendable (AgentLoopEvent) -> Void

public extension Notification.Name {
    static let lumiTurnStarted = Notification.Name("com.coffic.lumi.turnStarted")
    static let lumiMessageSaved = Notification.Name("com.coffic.lumi.messageSaved")
    static let lumiTurnCompleted = Notification.Name("com.coffic.lumi.turnCompleted")
    static let lumiTurnFinished = Notification.Name("com.coffic.lumi.turnFinished")
}
