import Foundation
import ProviderAgentLoop

/// 消息发送状态变化事件。
@MainActor
public enum MessageSenderEvent {
    case started(conversationID: UUID)
    case turnCompleted(conversationID: UUID, outcome: AgentLoopOutcome)
    case turnFailed(conversationID: UUID, reason: String)
    case attachmentsChanged
    case pendingMessagesChanged(conversationID: UUID)
}

@MainActor
public protocol MessageSenderObserverHandle: AnyObject {
    func cancel()
}
