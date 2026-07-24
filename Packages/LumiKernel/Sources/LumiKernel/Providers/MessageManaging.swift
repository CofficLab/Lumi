import Foundation

/// 消息管理能力协议
///
/// 定义消息的获取、删除、插入等管理功能。
@MainActor
public protocol MessageManaging: ObservableObject {
    /// 获取指定对话的所有消息
    func messages(for conversationID: UUID) -> [LumiChatMessage]

    /// 删除指定消息
    func deleteMessage(id: UUID, in conversationID: UUID)

    /// 插入新消息到指定对话
    func insertMessage(_ message: LumiChatMessage, to conversationID: UUID)

    /// 更新消息内容
    func updateMessage(id: UUID, in conversationID: UUID, content: String)

    /// 更新消息中的 tool call 结果
    ///
    /// 在 tool call 执行完成后，需要更新 assistant 消息中对应 toolCall 的 result 字段，
    /// 以便 UI 能够显示正确的视觉状态（成功/失败/执行时长）。
    func updateToolCallResult(
        _ result: LumiToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID
    )

    /// 清空指定对话的所有消息
    func clearMessages(in conversationID: UUID)

    /// 获取指定消息
    func message(id: UUID, in conversationID: UUID) -> LumiChatMessage?

    /// 获取指定对话的最后一个消息
    func lastMessage(in conversationID: UUID) -> LumiChatMessage?
}
