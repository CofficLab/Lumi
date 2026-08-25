import Combine
import Foundation

/// 选中对话变化观察者的注册令牌。
///
/// 调用 `ConversationManaging.addSelectedConversationObserver(_:)` 后持有返回值
/// 即可持续接收选中对话变化通知；令牌释放（deinit）或显式调用 `cancel()` 时
/// 自动停止接收，无需手动反注册。
@MainActor
public protocol SelectedConversationObserverHandle: AnyObject {
    /// 停止接收选中对话变化通知。重复调用无副作用。
    func cancel()
}

/// 对话管理能力协议
///
/// 定义对话的列表、创建、删除、选择等管理功能。
///
/// 复刻自旧版内核 KernelLumi 的 `ConversationManaging`，去掉对 KernelLumi /
/// 事件总线 / 具体存储实现的依赖，使协议存在类型（`any ConversationManaging`）
/// 可被 SwiftUI 跨包响应式观察 + Hook 订阅。
///
/// `ObjectWillChangePublisher == ObservableObjectPublisher` 约束与 `ProjectProviding`
/// 一致，用于让协议存在类型的 `objectWillChange` 可被订阅。
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

    /// 全库中「不同项目路径」的数量（仅统计 projectPath 非空、顶层对话）。
    ///
    /// 用于判断按项目筛选是否有意义：当数量 ≤1 时，所有顶层对话都来自同一个项目，
    /// 「全部对话」视图已等同于该项目，「当前项目」筛选入口冗余，应隐藏。
    func conversationProjectCount() async -> Int

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

    // MARK: - Selected Conversation Observation

    /// 注册一个观察者：当 `selectedConversationID` 变化时（含取消选择变为 nil），
    /// 通过 callback 收到最新选中对话 ID。
    ///
    /// 回调在主线程（`@MainActor`）同步执行，携带变化后的 `selectedConversationID`。
    /// 只有选中值实际发生变化时才会触发，重复设置同一值不会重复通知。
    ///
    /// - Parameter callback: 选中对话变化时的通知回调，参数为最新选中 ID（可为 nil）。
    /// - Returns: 注销令牌；持有返回值即可持续接收，令牌释放（deinit）或调用
    ///   `cancel()` 后自动停止接收。
    @discardableResult
    func addSelectedConversationObserver(_ callback: @escaping (UUID?) -> Void) -> any SelectedConversationObserverHandle

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

    /// 全局推理强度（用于新对话的默认值；nil 表示关闭思考）。
    var globalReasoningEffort: LumiReasoningEffort? { get }

    /// 设置全局推理强度（nil 表示关闭思考）。
    func setGlobalReasoningEffort(_ reasoningEffort: LumiReasoningEffort?)

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

    /// 全局对话模式（用于新对话的默认值）
    var globalAutomationLevel: LumiAutomationLevel { get }

    /// 设置全局对话模式
    func setGlobalAutomationLevel(_ automationLevel: LumiAutomationLevel)

    /// 获取指定对话的自动化程度
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel

    /// 设置指定对话的自动化程度
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?)

    // MARK: - Language

    /// 全局回复语言（用于新对话的默认值）
    var globalLanguage: LumiConversationLanguage { get }

    /// 设置全局回复语言
    func setGlobalLanguage(_ language: LumiConversationLanguage)

    /// 获取指定对话的回复语言
    func language(for conversationID: UUID?) -> LumiConversationLanguage

    /// 设置指定对话的回复语言
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?)
}

/// Lightweight compatibility defaults for providers and test doubles that do
/// not need paginated conversation storage.
public extension ConversationManaging {
    var sortedConversations: [LumiConversationSummary] { conversations }
    var isLoadingConversations: Bool { false }

    func fetchConversationPage(limit: Int, beforeUpdatedAt: Date?, beforeID: UUID?) async -> [LumiConversationSummary] {
        Array(conversations.prefix(limit))
    }

    func fetchConversationPage(limit: Int, beforeUpdatedAt: Date?, beforeID: UUID?, includingChildConversations: Bool) async -> [LumiConversationSummary] {
        await fetchConversationPage(limit: limit, beforeUpdatedAt: beforeUpdatedAt, beforeID: beforeID)
    }

    func fetchConversationPage(limit: Int, beforeUpdatedAt: Date?, beforeID: UUID?, includingChildConversations: Bool, projectPath: String) async -> [LumiConversationSummary] {
        await fetchConversationPage(limit: limit, beforeUpdatedAt: beforeUpdatedAt, beforeID: beforeID, includingChildConversations: includingChildConversations)
    }

    func fetchConversation(id: UUID) async -> LumiConversationSummary? {
        conversations.first(where: { $0.id == id })
    }

    func conversationCount(projectPath: String?) async -> Int { conversations.count }
    func conversationCount(projectPath: String?, includingChildConversations: Bool) async -> Int { conversations.count }
    func conversationProjectCount() async -> Int { Set(conversations.compactMap(\.projectPath)).count }
}

/// no-op 注册令牌：注册后不接收任何通知。
///
/// 协议不再提供默认实现，未实现选中观察者能力的轻量实现（如测试 mock）
/// 可显式返回本令牌，保证调用方拿到令牌后仍可按统一方式持有与释放。
@MainActor
public final class NoopSelectedConversationObserverHandle: SelectedConversationObserverHandle {
    public init() {}
    public func cancel() {}
}
