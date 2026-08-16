import Combine
import Foundation

@MainActor
public protocol MessageManaging: AnyObject, ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    func messages(for conversationID: UUID) -> [Message]
    func message(id: UUID, in conversationID: UUID) -> Message?
    func lastMessage(in conversationID: UUID) -> Message?
    func messageCount(for conversationID: UUID) -> Int
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

    /// 清掉指定会话的瞬时 status 消息（"正在发送…"/"正在思考…"等）。
    ///
    /// 回合结束（含取消、失败）时调用，避免状态行残留在时间线上；
    /// 实现可依赖 `Message.metadata["isTransientStatus"] == "true"` 识别。
    func clearStatusMessages(in conversationID: UUID)
}

public extension MessageManaging {
    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID
    ) {}

    func clearStatusMessages(in conversationID: UUID) {}
}
