import Foundation
import LumiCoreMessage

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

    /// 清空指定对话的所有消息
    func clearMessages(in conversationID: UUID)
}
