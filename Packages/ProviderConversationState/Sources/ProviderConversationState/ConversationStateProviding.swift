import Combine
import Foundation
import ProviderAgentLoop

/// 工具阶段。它只描述观察到的工具生命周期，不负责执行或授权。
public enum ConversationToolState: String, Codable, Sendable {
    case idle
    case executing
    case suspended
    case completed
}
/// 当前会话是否有等待用户处理的授权请求。
public enum ConversationAuthorizationState: String, Codable, Sendable {
    case none
    case required
}

/// 当前会话面向用户的瞬时活动，不属于消息时间线。
public enum ConversationActivity: String, Codable, Sendable, Equatable {
    case sending
    case thinking
    case executingTool
    case waitingForUser
}

/// 一个会话的当前状态快照。
public struct ConversationStateSnapshot: Equatable, Sendable {
    public let conversationID: UUID
    public let turnID: UUID?
    public let agentLoopState: AgentLoopState
    public let toolState: ConversationToolState
    public let authorizationState: ConversationAuthorizationState
    public let activity: ConversationActivity?
    public let lastError: String?

    /// 当前会话是否正在执行 Agent 回合。
    public var isSending: Bool {
        agentLoopState == .running
    }

    public init(
        conversationID: UUID,
        turnID: UUID? = nil,
        agentLoopState: AgentLoopState = .idle,
        toolState: ConversationToolState = .idle,
        authorizationState: ConversationAuthorizationState = .none,
        activity: ConversationActivity? = nil,
        lastError: String? = nil
    ) {
        self.conversationID = conversationID
        self.turnID = turnID
        self.agentLoopState = agentLoopState
        self.toolState = toolState
        self.authorizationState = authorizationState
        self.activity = activity
        self.lastError = lastError
    }
}
@MainActor
public enum ConversationStateEvent: Sendable, Equatable {
    case updated(UUID)
    case removed(UUID)
}

@MainActor
public protocol ConversationStateObserverHandle: AnyObject {
    func cancel()
}

@MainActor
public protocol ConversationStateProviding: AnyObject, ObservableObject
where ObjectWillChangePublisher == ObservableObjectPublisher {
    func state(for conversationID: UUID) -> ConversationStateSnapshot
    var states: [UUID: ConversationStateSnapshot] { get }

    @discardableResult
    func addConversationStateObserver(
        _ callback: @escaping (ConversationStateEvent) -> Void
    ) -> any ConversationStateObserverHandle
}

public extension ConversationStateProviding {
    @discardableResult
    func addConversationStateObserver(
        _ callback: @escaping (ConversationStateEvent) -> Void
    ) -> any ConversationStateObserverHandle {
        NoopConversationStateObserverHandle()
    }
}
