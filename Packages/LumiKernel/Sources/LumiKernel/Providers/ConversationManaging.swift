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
    ///
    /// The cursor is the last item from the previous page. Implementations
    /// should use keyset pagination so callers do not need to load the full
    /// conversation history into memory.
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
    ///
    /// - Parameters:
    ///   - title: 对话标题（可选）
    ///   - projectPath: 关联项目路径（可选，传 nil 则自动使用当前项目）
    ///   - providerID: 供应商 ID（可选，传 nil 则自动使用当前选中的供应商）
    ///   - modelName: 模型名称（可选，传 nil 则自动使用当前选中的模型）
    /// - Returns: 新对话 ID
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
    ///
    /// - Parameters:
    ///   - title: 新标题
    ///   - conversationID: 目标对话 ID
    /// - Returns: 更新成功返回 `true`，对话不存在返回 `false`
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool

    // MARK: - Activity

    /// 标记对话为活跃(收到新消息)，刷新其更新时间使其在「最近更新」排序中置顶。
    ///
    /// 由消息写入路径在会话收到非 status 消息时调用。实现应更新内存缓存与
    /// 持久化时间戳，并广播 `conversationsDidChange` 以便对话列表重新排序。
    func markConversationActive(id: UUID)

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

    /// 全局详细程度（单一数据源）
    ///
    /// 由 `StateMonitorPlugin` 负责与当前对话的双向同步：
    /// - 全局变化 → 同步到当前对话
    /// - 切换对话 → 用新对话的详细程度更新全局
    var globalVerbosity: LumiResponseVerbosity { get }

    /// 设置全局详细程度
    ///
    /// 由 `ConversationVerbosityPlugin` 调用，不直接操作某个对话。
    func setGlobalVerbosity(_ verbosity: LumiResponseVerbosity)

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

    /// 按更新时间倒序排序
    var sortedConversations: [LumiConversationSummary] {
        conversations.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    /// 默认空实现，测试 mock 无需自行实现即可编译通过
    func deselectConversation() {}

    /// 默认空实现，测试 mock 无需自行实现即可编译通过
    func markConversationActive(id: UUID) {}
}
