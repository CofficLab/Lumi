import Foundation
import os
import SuperLogKit

/// GoalTaskPlugin 的通用视图模型。
///
/// 由 `Plugin` 持有并管理生命周期,跨视图重建保留订阅与加载状态;
/// 通过 `managerProvider` 注入数据源,默认仍走 `GoalTaskPlugin.currentManager()`。
///
/// 当前职责:
/// - 跟踪 `currentConversationID`(由 `GoalRootView` 监听对话切换事件并写入)
/// - 拉取并缓存当前对话的 `goals: [GoalListItem]`,供 `SidebarView` 与工具栏按钮复用
///
/// 并发:与 `Plugin` 同处 `MainActor`。
@MainActor
final class GoalVM: ObservableObject, SuperLog {
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = GoalTaskPlugin.logger
    public nonisolated static let emoji = "🇫🇯"

    /// 数据源提供器;注入点允许外部传入自定义 `GoalStateManager`(测试 / 多实例场景)。
    private let managerProvider: () -> GoalStateManager?

    @Published var currentConversationID: UUID?

    /// 当前对话的所有 Goal(每个携带自己的任务),按创建时间升序。
    @Published public var goals: [GoalListItem] = []

    /// 是否正在拉取 Goal 列表。
    @Published public var isLoading: Bool = false

    public init(managerProvider: @escaping () -> GoalStateManager? = { GoalTaskPlugin.currentManager() }) {
        self.managerProvider = managerProvider
    }

    /// 是否有活跃(非终态)Goal,供外部判断按钮启用状态 / 空态文案。
    public var hasActiveGoal: Bool {
        goals.contains { (item: GoalListItem) in item.goal.isTerminal == false }
    }

    /// 更新当前对话 ID。
    ///
    /// - 当传入值与当前值一致时,跳过发布以避免触发不必要的 SwiftUI 重渲染。
    /// - 传入 `nil` 时表示清空当前对话上下文(例如对话被关闭或切换)。
    public func updateCurrentConversationID(_ id: UUID?) {
        guard currentConversationID != id else {
            if Self.verbose {
                Self.logger.info("\(Self.t)currentConversationID 未变化,跳过更新:\(id?.uuidString ?? "nil")")
            }
            return
        }
        let previous = currentConversationID
        currentConversationID = id
        if Self.verbose {
            Self.logger.info("\(Self.t)currentConversationID 更新:\(previous?.uuidString ?? "nil") -> \(id?.uuidString ?? "nil")")
        }
    }

    /// 刷新当前对话的 Goal 列表。
    ///
    /// - 无 `currentConversationID` 时清空 `goals` 并直接返回。
    /// - 无 `managerProvider` 时静默跳过(由调用方按需决定是否降级)。
    public func refresh() async {
        guard let manager = managerProvider() else {
            if Self.verbose {
                Self.logger.info("\(Self.t)refresh 跳过:manager 不可用")
            }
            return
        }

        guard let conversationId = currentConversationID else {
            goals = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        let fetchedGoals = await manager.fetchGoals(conversationId: conversationId.uuidString)

        // 逐个加载每个 goal 的任务(SwiftData 关系跨 ModelContext 不可靠,必须显式查询)。
        var items: [GoalListItem] = []
        for goal in fetchedGoals {
            let tasks = await manager.fetchTasks(goalId: goal.id)
            items.append(GoalListItem(
                goal: GoalDisplayItem(from: goal),
                tasks: tasks.map { GoalTaskDisplayItem(from: $0) }
            ))
        }
        goals = items

        if Self.verbose {
            Self.logger.info("\(Self.t)refresh 完成:conversation=\(conversationId.uuidString) count=\(items.count)")
        }
    }
}