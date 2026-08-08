import Combine
import Foundation

/// 对话管理能力协议
///
/// 定义对话的列表、创建、删除、选择等管理功能。
///
/// `ObjectWillChangePublisher == ObservableObjectPublisher` 约束与 `ProjectProviding` 一致，
/// 用于让协议存在类型（`any ConversationManaging`）的 `objectWillChange` 可被订阅，
/// 从而支持 SwiftUI 跨包响应式观察 + Hook 订阅。
@MainActor
public protocol ConversationManaging: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 所有对话列表
    var conversations: [LumiConversationSummary] { get }

    /// 按排序规则排序后的对话列表：置顶优先，然后按更新时间倒序
    var sortedConversations: [LumiConversationSummary] { get }

    /// 当前选中的对话 ID
    var selectedConversationID: UUID? { get }

    /// 当前选中对话的标题
    var currentTitle: String { get }

    /// Whether the initial conversation list is still being loaded.
    ///
    /// Implementations that load synchronously can use the default value.
    var isLoadingConversations: Bool { get }

    /// Fetch one page of conversations ordered by most recently updated.
    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?
    ) async -> [LumiConversationSummary]

    /// Fetch one page, optionally including conversations created by sub-agents.
    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?,
        includingChildConversations: Bool
    ) async -> [LumiConversationSummary]

    /// Fetch one page of conversations filtered by project path.
    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?,
        includingChildConversations: Bool,
        projectPath: String
    ) async -> [LumiConversationSummary]

    /// Fetch one conversation summary by ID without requiring the full list.
    func fetchConversation(id: UUID) async -> LumiConversationSummary?

    /// Count conversations without loading their summaries.
    func conversationCount(projectPath: String?) async -> Int

    /// Count conversations, optionally including conversations created by sub-agents.
    func conversationCount(projectPath: String?, includingChildConversations: Bool) async -> Int

    /// 数据存储目录
    var dataDirectory: URL { get }

    /// 创建新对话
    func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?) throws -> UUID

    /// Creates a conversation with an optional parent conversation.
    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?,
        parentConversationID: UUID?
    ) throws -> UUID

    /// 选择对话
    func selectConversation(id: UUID)

    /// 取消选择当前对话（将 selectedConversationID 置为 nil）
    func deselectConversation()

    /// 删除对话
    func deleteConversation(id: UUID)

    /// 更新指定对话的标题
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool

    // MARK: - Activity

    /// 标记对话为活跃(收到新消息)
    func markConversationActive(id: UUID, messageDate: Date)

    /// 检查对话是否正在发送中
    func isSending(for conversationID: UUID?) -> Bool

    // MARK: - Provider/Model

    /// 获取指定对话绑定的供应商 ID
    func providerID(for conversationID: UUID?) -> String?

    /// 获取指定对话绑定的模型名称
    func modelName(for conversationID: UUID?) -> String?

    /// 为指定对话设置供应商和模型
    func selectProvider(id: String, model: String?, for conversationID: UUID?)

    // MARK: - Verbosity

    /// 全局详细程度（用于未绑定详细程度的对话的默认值）
    var globalVerbosity: LumiResponseVerbosity { get }

    /// 设置全局详细程度
    func setGlobalVerbosity(_ verbosity: LumiResponseVerbosity)

    /// 更新指定对话的详细程度
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?)

    /// 获取指定对话的详细程度
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity

    // MARK: - Reasoning Effort

    /// 获取指定对话的推理强度
    func reasoningEffort(for conversationID: UUID?) -> LumiReasoningEffort

    /// 获取指定对话的推理强度（可选版本，用于需要区分 nil 状态的场景，如 toggle 模型）。
    /// - nil 表示思考已关闭
    /// - 非 nil 表示思考已开启，并指定具体档位
    func reasoningEffortOptional(for conversationID: UUID?) -> LumiReasoningEffort?

    /// 设置指定对话的推理强度
    func setReasoningEffort(_ reasoningEffort: LumiReasoningEffort, for conversationID: UUID?)

    /// 清除/关闭指定对话的推理强度（用于 toggle 模型）。
    func clearReasoningEffort(for conversationID: UUID?)

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

// MARK: - Default Implementations

public extension ConversationManaging {
    var isLoadingConversations: Bool { false }

    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil
    ) async -> [LumiConversationSummary] {
        []
    }

    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil,
        includingChildConversations: Bool
    ) async -> [LumiConversationSummary] {
        await fetchConversationPage(limit: limit, beforeUpdatedAt: beforeUpdatedAt, beforeID: beforeID)
    }

    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date? = nil,
        beforeID: UUID? = nil,
        includingChildConversations: Bool,
        projectPath: String
    ) async -> [LumiConversationSummary] {
        await fetchConversationPage(limit: limit, beforeUpdatedAt: beforeUpdatedAt, beforeID: beforeID, includingChildConversations: includingChildConversations)
    }

    func fetchConversation(id: UUID) async -> LumiConversationSummary? {
        nil
    }

    func conversationCount(projectPath: String?) async -> Int {
        0
    }

    func conversationCount(projectPath: String?, includingChildConversations: Bool) async -> Int {
        await conversationCount(projectPath: projectPath)
    }

    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?,
        parentConversationID: UUID?
    ) throws -> UUID {
        try createConversation(title: title, projectPath: projectPath, providerID: providerID, modelName: modelName)
    }

    /// 按最后消息时间倒序排序
    var sortedConversations: [LumiConversationSummary] {
        conversations.sorted { lhs, rhs in
            if lhs.lastMessageAt == rhs.lastMessageAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.lastMessageAt > rhs.lastMessageAt
        }
    }

    /// 默认空实现，测试 mock 无需自行实现即可编译通过
    func deselectConversation() {}

    /// 默认空实现，测试 mock 无需自行实现即可编译通过
    func markConversationActive(id: UUID, messageDate: Date) {}

    /// 默认实现：返回非可选版本的值（nil 时返回 defaultEffort）
    func reasoningEffortOptional(for conversationID: UUID?) -> LumiReasoningEffort? {
        reasoningEffort(for: conversationID)
    }
}
