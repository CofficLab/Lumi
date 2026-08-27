import Combine
import Foundation

/// 消息插入观察者的注册令牌。
///
/// 调用 `MessageManaging.addMessageInsertedObserver(_:)` 后持有返回值
/// 即可持续接收消息插入通知；不再需要时显式调用 `cancel()` 停止接收。
@MainActor
public protocol MessageInsertedObserverHandle: AnyObject {
    /// 停止接收消息插入通知。重复调用无副作用。
    func cancel()
}

@MainActor
public protocol MessageManaging: AnyObject, ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    func messages(for conversationID: UUID) -> [Message]
    func message(id: UUID, in conversationID: UUID) -> Message?
    func lastMessage(in conversationID: UUID) -> Message?
    func messageCount(for conversationID: UUID) -> Int
    /// 返回指定日期（含）以来、按本地日历日聚合的消息数量。
    ///
    /// 活动热力图等跨会话统计功能使用此接口；实现必须包含所有会话，
    /// 并将 key 规范化为 `Calendar.current.startOfDay(for:)`。
    func dailyMessageCounts(since: Date) -> [Date: Int]
    /// 返回指定日期（含）以来、按本地日历日聚合的输入和输出 token 总量。
    func dailyTokenCounts(since: Date) -> [Date: Int]
    func insertMessage(_ message: Message, to conversationID: UUID)
    func updateMessage(id: UUID, in conversationID: UUID, content: String)
    func deleteMessage(id: UUID, in conversationID: UUID)
    func clearMessages(in conversationID: UUID)

    /// 更新某条 assistant 消息中指定工具调用的结果（渲染层展示成功/失败/耗时）。
    ///
    /// 对齐旧版 `MessageManaging.updateToolCallResult`。工具调用结果落库由
    /// 单独的 `.tool` 消息承担；此处仅更新 assistant 消息内的展示快照。
    /// 消息或工具调用不存在时静默忽略。
    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID
    )

    // MARK: - Observation

    /// 注册一个观察者：当 `insertMessage` 被调用后通过 callback 收到插入的消息和会话 ID。
    ///
    /// 回调在主线程同步执行。仅在消息成功插入（写入内存缓冲）后触发。
    /// status 消息也会触发回调。
    ///
    /// - Parameter callback: 消息插入时的通知回调，参数为 (消息, 会话 ID)。
    /// - Returns: 注销令牌；持有返回值即可持续接收，令牌释放或调用 `cancel()` 后自动停止。
    @discardableResult
    func addMessageInsertedObserver(
        _ callback: @escaping (Message, UUID) -> Void
    ) -> any MessageInsertedObserverHandle
}

public extension MessageManaging {
    func dailyMessageCounts(since: Date) -> [Date: Int] { [:] }

    func dailyTokenCounts(since: Date) -> [Date: Int] { [:] }

    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID
    ) {}


    func addMessageInsertedObserver(
        _ callback: @escaping (Message, UUID) -> Void
    ) -> any MessageInsertedObserverHandle {
        NoopMessageInsertedObserverHandle()
    }
}

// MARK: - No-op handle (default implementation)

@MainActor
private final class NoopMessageInsertedObserverHandle: MessageInsertedObserverHandle {
    func cancel() {}
}
