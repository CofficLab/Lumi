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

    /// 当前选中对话的标题
    var currentTitle: String { get }

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

    /// 返回模拟对话 ID 列表（用于测试数据关联）
    func mockConversationIDs() -> [UUID]

    // MARK: - Provider/Model Selection

    /// 获取指定对话的 Provider ID
    func providerID(for conversationID: UUID?) -> String?

    /// 获取指定对话的 Model 名称
    func modelName(for conversationID: UUID?) -> String?

    /// 设置指定对话的 Provider 和 Model
    func selectProvider(id: String, model: String?, for conversationID: UUID?)

    // MARK: - Verbosity

    /// 获取指定对话的详细程度
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity

    /// 设置指定对话的详细程度
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?)

    // MARK: - Automation Level

    /// 获取指定对话的自动化程度
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel

    /// 设置指定对话的自动化程度
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?)
}
