import Foundation
import KitAgentTool

/// 工具执行生命周期事件。
@MainActor
public enum ToolManagerEvent {
    case started(conversationID: UUID, turnID: UUID?, toolCall: ToolCall)
    case completed(conversationID: UUID, turnID: UUID?, toolCall: ToolCall, result: ToolCallResult)
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
