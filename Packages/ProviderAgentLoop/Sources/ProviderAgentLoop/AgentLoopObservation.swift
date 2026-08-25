import Foundation
import ProviderMessage

/// Agent 回合生命周期事件。
@MainActor
public enum AgentLoopEvent {
    case started(conversationID: UUID, turnID: UUID)
    case llmResponseReceived(conversationID: UUID, turnID: UUID, toolCalls: [MessageToolCall])
    case suspended(conversationID: UUID, turnID: UUID, suspension: AgentLoopSuspension)
    case completed(conversationID: UUID, turnID: UUID)
    case failed(conversationID: UUID, turnID: UUID, reason: String)
    case cancelled(conversationID: UUID, turnID: UUID?)
}

@MainActor
public protocol AgentLoopObserverHandle: AnyObject {
    func cancel()
}

public extension AgentLoopProviding {
    /// 注册 Agent 回合观察者。默认实现为空，保持旧版测试桩和第三方实现兼容。
    @discardableResult
    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        NoopAgentLoopObserverHandle()
    }
}

@MainActor
private final class NoopAgentLoopObserverHandle: AgentLoopObserverHandle {
    func cancel() {}
}
