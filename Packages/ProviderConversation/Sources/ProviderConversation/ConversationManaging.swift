import Foundation
import KitLLM

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
/// 可被 SwiftUI 跨包读取，并通过语义事件订阅变化。
@MainActor
public protocol ConversationManaging: AnyObject {
    /// 所有对话列表
    var conversations: [ConversationSummary] { get }

    /// 按排序规则排序后的对话列表：置顶优先，然后按更新时间倒序
    var sortedConversations: [ConversationSummary] { get }

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
    ) async -> [ConversationSummary]

    /// Fetch one page, optionally including conversations created by sub-agents.
    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?,
        includingChildConversations: Bool
    ) async -> [ConversationSummary]

    /// Fetch one page of conversations filtered by project path.
    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?,
        includingChildConversations: Bool,
        projectPath: String
    ) async -> [ConversationSummary]

    /// Fetch one conversation summary by ID without requiring the full list.
    func fetchConversation(id: UUID) async -> ConversationSummary?

    /// 返回仍然**没有标题**的对话 ID。
    ///
    /// 标题生成失败过的对话会永久停在「无标题」状态，在列表里只能显示通用
    /// 占位符，看起来就是一条空条目。调用方拿到这些 ID 后可以为它们补写
    /// 标题（例如用首条用户消息作为占位标题）。
    ///
    /// - Parameter limit: 最多返回多少个 ID。
    func untitledConversationIDs(limit: Int) async -> [UUID]

    /// Count conversations without loading their summaries.
    func conversationCount(projectPath: String?) async -> Int

    /// Count conversations, optionally including conversations created by sub-agents.
    func conversationCount(projectPath: String?, includingChildConversations: Bool) async -> Int

    /// 全库中「不同项目路径」的数量（仅统计 projectPath 非空、顶层对话）。
    ///
    /// 用于判断按项目筛选是否有意义：当数量 ≤1 时，所有顶层对话都来自同一个项目，
    /// 「全部对话」视图已等同于该项目，「当前项目」筛选入口冗余，应隐藏。
    func conversationProjectCount() async -> Int

    /// 每日对话计数序列（按创建日聚合）。
    ///
    /// - Parameters:
    ///   - days: 序列长度（向前回溯的天数）。
    ///   - projectPath: 只统计该项目的对话；`nil` 表示全部项目。
    ///   - includingChildConversations: 是否把子 Agent 会话计入。
    func fetchDailyCountSeries(
        days: Int,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> ConversationDailyCountSeries

    /// 统计「创建于 `cutoff` 之前」的对话数量。
    ///
    /// 用于在执行批量清理前告知用户将被删除的条数。
    ///
    /// - Parameters:
    ///   - cutoff: 时间分界点；`createdAt` 早于它的会话命中。
    ///   - projectPath: 只统计该项目的对话；`nil` 表示全部项目。
    ///   - includingChildConversations: 是否把子 Agent 会话计入。
    func conversationCount(
        createdBefore cutoff: Date,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> Int

    /// 删除「创建于 `cutoff` 之前」的对话，返回被删除的会话 ID。
    ///
    /// 用于「清理 N 天前的对话」这类按时间批量清理的入口。
    ///
    /// - Parameters:
    ///   - cutoff: 时间分界点；`createdAt` 早于它的会话会被删除。
    ///   - projectPath: 只清理该项目的对话；`nil` 表示全部项目。
    ///   - includingChildConversations: 是否连带删除子 Agent 会话。
    /// - Returns: 被删除的会话 ID 列表。
    @discardableResult
    func deleteConversations(
        createdBefore cutoff: Date,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> [UUID]

    /// 返回指定项目下、且在给定时间点之后仍有活动的会话 ID（`uuidString`）。
    ///
    /// ## 用途
    ///
    /// 消息统计需要「哪些消息属于这个项目」这个判定，但消息存储里只有会话 ID，
    /// 项目归属存在会话存储里。会话集合由这里提供，消息存储再按会话 ID 过滤。
    ///
    /// ## 参数
    ///
    /// - Parameters:
    ///   - projectPath: 项目根目录路径。
    ///   - updatedSince: 只保留在该时间点之后仍有活动的会话；nil 表示不限时间。
    ///     传入窗口起点（例如「近 30 天的起点」）可以把结果集限制在窗口内。
    ///
    /// - Returns: 会话 ID 字符串列表；项目下没有会话时为空数组。
    func conversationIDs(projectPath: String, updatedSince: Date?) async -> [String]

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

    /// 注册对话领域事件观察者。
    ///
    /// 事件只描述语义变化，适合需要区分创建、删除、偏好修改等场景的消费者；
    /// UI 刷新也应通过这些语义事件驱动。
    @discardableResult
    func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle

    /// 将当前实现上注册的观察者迁移到新的实现。
    func transferObservers(to replacement: any ConversationManaging)

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

    /// 获取对话绑定的全局唯一模型 ID。
    func modelID(for conversationID: UUID?) -> String?

    /// 为指定对话设置全局唯一模型 ID。
    func selectModel(id: String, for conversationID: UUID?)

    /// 获取指定对话绑定的供应商 ID
    func providerID(for conversationID: UUID?) -> String?

    /// 获取指定对话绑定的模型名称
    func modelName(for conversationID: UUID?) -> String?

    /// 为指定对话设置供应商和模型
    func selectProvider(id: String, model: String?, for conversationID: UUID?)

    // MARK: - Verbosity

    /// 全局详细程度（用于未绑定详细程度的对话的默认值）
    var globalVerbosity: ResponseVerbosity { get }

    /// 设置全局详细程度
    func setGlobalVerbosity(_ verbosity: ResponseVerbosity)

    /// 更新指定对话的详细程度
    func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?)

    /// 获取指定对话的详细程度
    func verbosity(for conversationID: UUID?) -> ResponseVerbosity

    /// 更新指定对话的详细程度，并等待持久化完成（如实现支持持久化）。
    /// 轻量实现可直接复用同步 setter。
    func setVerbosityAndWait(_ verbosity: ResponseVerbosity, for conversationID: UUID?) async

    // MARK: - Reasoning Effort

    /// 全局推理强度（用于新对话的默认值；nil 表示关闭思考）。
    var globalReasoningEffort: ReasoningEffort? { get }

    /// 设置全局推理强度（nil 表示关闭思考）。
    func setGlobalReasoningEffort(_ reasoningEffort: ReasoningEffort?)

    /// 获取指定对话的推理强度
    func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort

    /// 获取指定对话的推理强度（可选版本，用于需要区分 nil 状态的场景，如 toggle 模型）。
    /// - nil 表示思考已关闭
    /// - 非 nil 表示思考已开启，并指定具体档位
    func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort?

    /// 设置指定对话的推理强度
    func setReasoningEffort(_ reasoningEffort: ReasoningEffort, for conversationID: UUID?)

    /// 清除/关闭指定对话的推理强度（用于 toggle 模型）。
    func clearReasoningEffort(for conversationID: UUID?)

    // MARK: - Automation Level

    /// 全局对话模式（用于新对话的默认值）
    var globalAutomationLevel: AutomationLevel { get }

    /// 设置全局对话模式
    func setGlobalAutomationLevel(_ automationLevel: AutomationLevel)

    /// 获取指定对话的自动化程度
    func automationLevel(for conversationID: UUID?) -> AutomationLevel

    /// 设置指定对话的自动化程度
    func setAutomationLevel(_ automationLevel: AutomationLevel, for conversationID: UUID?)

    // MARK: - Language

    /// 全局回复语言（用于新对话的默认值）
    var globalLanguage: ConversationLanguage { get }

    /// 设置全局回复语言
    func setGlobalLanguage(_ language: ConversationLanguage)

    /// 获取指定对话的回复语言
    func language(for conversationID: UUID?) -> ConversationLanguage

    /// 设置指定对话的回复语言
    func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?)
}

public extension ConversationManaging {
    /// 默认实现：从已加载的会话摘要里筛出属于该项目且仍在活动期内的会话。
    ///
    /// 持久化实现应当走存储层查询，避免依赖「摘要已全部加载」这个前提。
    func conversationIDs(projectPath: String, updatedSince: Date?) async -> [String] {
        conversations.compactMap { summary in
            guard summary.projectPath == projectPath else { return nil }
            if let updatedSince, summary.updatedAt < updatedSince { return nil }
            return summary.id.uuidString
        }
    }

    func modelID(for conversationID: UUID?) -> String? {
        guard let providerID = providerID(for: conversationID),
              let modelName = modelName(for: conversationID) else { return nil }
        return LLMModelID(providerID: providerID, modelID: modelName)?.rawValue
    }

    func selectModel(id: String, for conversationID: UUID?) {
        guard let modelID = LLMModelID(rawValue: id) else { return }
        selectProvider(id: modelID.providerID, model: modelID.modelID, for: conversationID)
    }

    func createConversation(title: String?, projectPath: String?, modelID: String?) throws -> UUID {
        let parsed = modelID.flatMap(LLMModelID.init(rawValue:))
        return try createConversation(
            title: title,
            projectPath: projectPath,
            providerID: parsed?.providerID,
            modelName: parsed?.modelID
        )
    }

    func createConversation(
        title: String?,
        projectPath: String?,
        modelID: String?,
        parentConversationID: UUID?
    ) throws -> UUID {
        let parsed = modelID.flatMap(LLMModelID.init(rawValue:))
        return try createConversation(
            title: title,
            projectPath: projectPath,
            providerID: parsed?.providerID,
            modelName: parsed?.modelID,
            parentConversationID: parentConversationID
        )
    }
}

/// Lightweight compatibility defaults for providers and test doubles that do
/// not need paginated conversation storage.
public extension ConversationManaging {
    func setVerbosityAndWait(_ verbosity: ResponseVerbosity, for conversationID: UUID?) async {
        setVerbosity(verbosity, for: conversationID)
    }

    func transferObservers(to replacement: any ConversationManaging) {}

    func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle {
        NoopConversationObserverHandle()
    }

    var sortedConversations: [ConversationSummary] { conversations }
    var isLoadingConversations: Bool { false }

    func fetchConversationPage(limit: Int, beforeUpdatedAt: Date?, beforeID: UUID?) async -> [ConversationSummary] {
        Array(conversations.prefix(limit))
    }

    func fetchConversationPage(limit: Int, beforeUpdatedAt: Date?, beforeID: UUID?, includingChildConversations: Bool) async -> [ConversationSummary] {
        await fetchConversationPage(limit: limit, beforeUpdatedAt: beforeUpdatedAt, beforeID: beforeID)
    }

    func fetchConversationPage(limit: Int, beforeUpdatedAt: Date?, beforeID: UUID?, includingChildConversations: Bool, projectPath: String) async -> [ConversationSummary] {
        await fetchConversationPage(limit: limit, beforeUpdatedAt: beforeUpdatedAt, beforeID: beforeID, includingChildConversations: includingChildConversations)
    }

    func fetchConversation(id: UUID) async -> ConversationSummary? {
        conversations.first(where: { $0.id == id })
    }

    /// 默认实现：从已加载的会话摘要里筛出没有标题的对话。
    ///
    /// 持久化实现应当走存储层查询，避免依赖「摘要已全部加载」这个前提 ——
    /// 已加载的摘要只是一个有界的窗口，历史遗留的无标题对话很可能不在其中。
    func untitledConversationIDs(limit: Int) async -> [UUID] {
        guard limit > 0 else { return [] }
        return conversations
            .filter { !$0.hasCustomTitle }
            .prefix(limit)
            .map(\.id)
    }

    func conversationCount(projectPath: String?) async -> Int { conversations.count }
    func conversationCount(projectPath: String?, includingChildConversations: Bool) async -> Int { conversations.count }
    func conversationProjectCount() async -> Int { Set(conversations.compactMap(\.projectPath)).count }

    /// 默认实现：从已加载的会话摘要聚合每日计数。
    ///
    /// 持久化实现应当走存储层查询，避免依赖「摘要已全部加载」这个前提。
    func fetchDailyCountSeries(
        days: Int,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> ConversationDailyCountSeries {
        let records = conversations.map {
            ConversationCreationRecord(
                createdAt: $0.createdAt,
                projectPath: $0.projectPath,
                isChildConversation: $0.parentConversationID != nil
            )
        }
        return ConversationDailyCountSeries.build(
            from: records,
            days: days,
            projectPath: projectPath,
            includingChildConversations: includingChildConversations
        )
    }

    /// 默认实现：逐条删除命中的会话。
    func deleteConversations(
        createdBefore cutoff: Date,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> [UUID] {
        let targets = conversations.filter { summary in
            guard summary.createdAt < cutoff else { return false }
            if !includingChildConversations, summary.parentConversationID != nil { return false }
            if let projectPath, summary.projectPath != projectPath { return false }
            return true
        }
        for summary in targets {
            deleteConversation(id: summary.id)
        }
        return targets.map(\.id)
    }

    /// 默认实现：统计命中「创建于 `cutoff` 之前」的会话数量。
    func conversationCount(
        createdBefore cutoff: Date,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> Int {
        conversations.filter { summary in
            guard summary.createdAt < cutoff else { return false }
            if !includingChildConversations, summary.parentConversationID != nil { return false }
            if let projectPath, summary.projectPath != projectPath { return false }
            return true
        }.count
    }
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
