import Foundation
import KitAgentTool

/// 工具执行生命周期事件。
@MainActor
public enum ToolManagerEvent {
    case started(conversationID: UUID, turnID: UUID?, toolCall: ToolCall)
    case completed(conversationID: UUID, turnID: UUID?, toolCall: ToolCall, result: ToolCallResult)
    /// 用户授权后执行（或拒绝）单个工具的完成事件。
    ///
    /// 与 `completed` 分开，避免批量执行中的单工具完成事件被 AgentLoop
    /// 重复消费；该事件专门用于消息渲染器授权后的恢复路径。
    case authorizedCompleted(conversationID: UUID, turnID: UUID?, toolCall: ToolCall, result: ToolCallResult)
    case batchCompleted(conversationID: UUID, turnID: UUID?, toolCalls: [ToolCall], results: [BatchToolResult])
}

@MainActor
public protocol ToolManagerObserverHandle: AnyObject {
    func cancel()
}

public extension ToolManagerProviding {
    /// 注册工具执行观察者。默认实现为空，保持自定义 ToolManager 兼容。
    @discardableResult
    func addToolManagerObserver(
        _ callback: @escaping (ToolManagerEvent) -> Void
    ) -> any ToolManagerObserverHandle {
        NoopToolManagerObserverHandle()
    }
}

@MainActor
private final class NoopToolManagerObserverHandle: ToolManagerObserverHandle {
    func cancel() {}
}
