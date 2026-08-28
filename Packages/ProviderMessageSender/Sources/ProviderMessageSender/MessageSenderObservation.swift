import Foundation
import ProviderAgentLoop

/// 消息发送生命周期事件。
@MainActor
public enum MessageSenderEvent {
    case started(conversationID: UUID)
    case turnCompleted(conversationID: UUID, outcome: AgentLoopOutcome)
    case turnFailed(conversationID: UUID, reason: String)
}

@MainActor
public protocol MessageSenderObserverHandle: AnyObject {
    func cancel()
}
