import Foundation

// MARK: - Agent Loop Events
//
// 复刻自旧版 KernelLumi 的 `LumiEventManager` 通知（lumiTurnStarted /
// lumiMessageSaved / lumiTurnCompleted / lumiTurnFinished）。新版不再依赖
// KernelLumi：`DefaultAgentLoopProviding` 在回合关键节点回调 `AgentLoopEventHandler`，
// 由宿主（KernelFactory）把事件桥接到 KernelCoreEventBus 类型化事件 +
// 旧 NotificationCenter 通知名，让已迁移与未迁移的消费者都能收到。

/// 回合结束原因（对齐旧版 `LumiTurnEndReason`）。
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

// MARK: - 旧通知名兼容（与旧版 KernelLumi 完全一致）

public extension Notification.Name {
    static let lumiTurnStarted = Notification.Name("com.coffic.lumi.turnStarted")
    static let lumiMessageSaved = Notification.Name("com.coffic.lumi.messageSaved")
    static let lumiTurnCompleted = Notification.Name("com.coffic.lumi.turnCompleted")
    static let lumiTurnFinished = Notification.Name("com.coffic.lumi.turnFinished")
}
