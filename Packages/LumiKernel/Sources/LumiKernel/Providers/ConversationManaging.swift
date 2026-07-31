import Foundation

/// 对话管理能力协议
///
/// 定义对话的列表、创建、删除、选择等管理功能。
@MainActor
public protocol ConversationManaging: ObservableObject {
    /// 所有对话列表
    var conversations: [LumiConversationSummary] { get }

    /// 按排序规则排序后的对话列表：置顶优先，然后按更新时间倒序
    var sortedConversations: [LumiConversationSummary] { get }

    /// 当前选中的对话 ID
    var selectedConversationID: UUID? { get }

    /// 当前选中对话的标题
    var currentTitle: String { get }

    /// 数据存储目录
    var dataDirectory: URL { get }

    /// 创建新对话
    ///
    /// - Parameters:
    ///   - title: 对话标题（可选）
    ///   - projectPath: 关联项目路径（可选，传 nil 则自动使用当前项目）
    ///   - providerID: 供应商 ID（可选，传 nil 则自动使用当前选中的供应商）
    ///   - modelName: 模型名称（可选，传 nil 则自动使用当前选中的模型）
    /// - Returns: 新对话 ID
    func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?) throws -> UUID

    /// 选择对话
    func selectConversation(id: UUID)

    /// 删除对话
    func deleteConversation(id: UUID)

    /// 更新指定对话的标题
    ///
    /// - Parameters:
    ///   - title: 新标题
    ///   - conversationID: 目标对话 ID
    /// - Returns: 更新成功返回 `true`，对话不存在返回 `false`
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool

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

    // MARK: - Reasoning Effort

    /// 获取指定对话的推理强度
    func reasoningEffort(for conversationID: UUID?) -> LumiReasoningEffort

    /// 设置指定对话的推理强度
    func setReasoningEffort(_ reasoningEffort: LumiReasoningEffort, for conversationID: UUID?)

    // MARK: - Automation Level

    /// 获取指定对话的自动化程度
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel

    /// 设置指定对话的自动化程度
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?)

    // MARK: - Language

    /// 获取指定对话的回复语言
    func language(for conversationID: UUID?) -> LumiConversationLanguage

    /// 设置指定对话的回复语言
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?)
}

public extension ConversationManaging {
    /// 按更新时间倒序排序
    var sortedConversations: [LumiConversationSummary] {
        conversations.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}
