import Combine
import Foundation

/// 由消息管理器发布的结构化变化事件。
///
/// 插入事件携带已经进入内存 pending buffer 的消息，UI 可以直接应用它，
/// 不必为了显示一条刚发送的消息再次查询数据库。
public enum MessageChange: Sendable {
    case inserted(Message, conversationID: UUID)
}

/// 消息变化观察者注销令牌。
@MainActor
public protocol MessageChangeObserverHandle: AnyObject {
    func cancel()
}

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
    /// 异步读取指定会话的完整消息快照。实现应避免在 MainActor 执行磁盘读取、解码和排序。
    func messagesSnapshot(in conversationID: UUID) async -> [Message]
    /// 异步加载发送给 LLM 的消息历史。持久化实现应将磁盘读取和解码放到后台。
    func messagesForLLM(in conversationID: UUID) async -> [Message]
    /// 返回指定会话的一页消息，结果按时间升序排列。
    /// `beforeMessageID == nil` 时返回最新一页；否则返回游标之前的一页。
    func messagePage(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) -> [Message]
    /// 判断游标之前是否还有消息。传入 nil 时使用实现的默认探测窗口。
    func hasEarlierMessages(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) -> Bool
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
    /// `authorizationState` 非 nil 时，同时更新授权状态并持久化。
    /// 消息或工具调用不存在时静默忽略。
    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String?
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

    /// 注册结构化消息变化观察者。
    ///
    /// 回调在主线程同步执行。插入事件在消息进入内存缓冲后、后台落盘前发送。
    @discardableResult
    func addMessageChangeObserver(
        _ callback: @escaping (MessageChange) -> Void
    ) -> any MessageChangeObserverHandle
}

public extension MessageManaging {
    func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        await messagesForLLM(in: conversationID)
    }

    func messagesForLLM(in conversationID: UUID) async -> [Message] {
        messages(for: conversationID)
    }

    func messagePage(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool = false
    ) -> [Message] {
        guard limit > 0 else { return [] }
        let all = messages(for: conversationID)
            .filter { includesToolMessages || $0.role != .tool }
            .sorted {
                if $0.createdAt == $1.createdAt { return $0.id < $1.id }
                return $0.createdAt < $1.createdAt
            }
        guard let beforeMessageID else { return Array(all.suffix(limit)) }
        guard let index = all.firstIndex(where: { $0.id == beforeMessageID }) else { return [] }
        return Array(all[max(0, index - limit)..<index])
    }

    func hasEarlierMessages(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool = false
    ) -> Bool {
        let all = messages(for: conversationID)
            .filter { includesToolMessages || $0.role != .tool }
        guard let beforeMessageID else { return all.count > 10 }
        guard let index = all.firstIndex(where: { $0.id == beforeMessageID }) else { return false }
        return index > 0
    }

    func dailyMessageCounts(since: Date) -> [Date: Int] { [:] }

    func dailyTokenCounts(since: Date) -> [Date: Int] { [:] }

    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID
    ) {
        updateToolCallResult(
            result,
            toolCallID: toolCallID,
            assistantMessageID: assistantMessageID,
            in: conversationID,
            authorizationState: nil
        )
    }


    func addMessageInsertedObserver(
        _ callback: @escaping (Message, UUID) -> Void
    ) -> any MessageInsertedObserverHandle {
        NoopMessageInsertedObserverHandle()
    }

    func addMessageChangeObserver(
        _ callback: @escaping (MessageChange) -> Void
    ) -> any MessageChangeObserverHandle {
        NoopMessageChangeObserverHandle()
    }
}

// MARK: - No-op handle (default implementation)

@MainActor
private final class NoopMessageInsertedObserverHandle: MessageInsertedObserverHandle {
    func cancel() {}
}

@MainActor
private final class NoopMessageChangeObserverHandle: MessageChangeObserverHandle {
    func cancel() {}
}
