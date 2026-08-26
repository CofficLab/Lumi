import Foundation
import ProviderMessage

/// Agent 回合生命周期事件。
@MainActor
public enum AgentLoopEvent {
    case started(conversationID: UUID, turnID: UUID)
    /// LLM 已经返回工具调用。该事件表示一个 LLM step 结束，
    /// 不表示整个 Agent turn 完成；消费者应处理完工具结果后让回合继续。
    case toolCallsReceived(
        conversationID: UUID,
        turnID: UUID,
        assistantMessageID: UUID,
        toolCalls: [MessageToolCall]
    )
    /// 兼容旧实现的工具调用事件。新实现应发布并监听 `toolCallsReceived`。
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
