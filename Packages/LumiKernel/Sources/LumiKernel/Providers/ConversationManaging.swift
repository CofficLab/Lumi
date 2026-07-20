import Foundation

/// 对话管理能力协议
///
/// 定义对话的列表、创建、删除、选择等管理功能。
@MainActor
public protocol ConversationManaging: ObservableObject {
    /// 所有对话列表
    var conversations: [LumiConversationSummary] { get }

    /// 当前选中的对话 ID
    var selectedConversationID: UUID? { get }

    /// 数据存储目录
    var dataDirectory: URL { get }

    /// 创建新对话
    func createConversation(title: String?) throws -> UUID

    /// 选择对话
    func selectConversation(id: UUID)

    /// 删除对话
    func deleteConversation(id: UUID)

    /// 检查对话是否正在发送中
    func isSending(for conversationID: UUID?) -> Bool
}
