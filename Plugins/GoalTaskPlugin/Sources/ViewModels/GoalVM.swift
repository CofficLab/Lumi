import Foundation
import os
import SuperLogKit

/// GoalTaskPlugin 的唯一视图模型(已合并原 `SidebarViewModel`)。
///
/// 由 `Plugin` 持有并管理生命周期,跨视图重建保留订阅与加载状态;
/// 通过 `managerProvider` 注入数据源,默认仍走 `GoalTaskPlugin.currentManager()`。
///
/// 职责:
/// - 跟踪 `currentConversationID`(由 `SidebarView` 监听对话切换事件并写入)
/// - 拉取并缓存当前对话的 `goals: [GoalListItem]`,作为单一数据源
///   - 工具栏弹窗(`GoalPopoverContent`)直接消费 `goals`
///   - 侧栏(`SidebarView`)消费由 `goals` 派生的 `activeGoal` / `activeTasks` /
///     `hasActiveWork` / `progressText`
/// - 订阅 `.goalDidChange`,匹配当前会话时自动 reload
///
/// 并发:与 `Plugin` 同处 `MainActor`。每次加载都用 `expectedID` 守卫,在每个
/// `await` 边界之后重新比对 `currentConversationID`,丢弃已被新切换覆盖的陈旧响应,
/// 避免快速切换对话时显示上一个对话的残留 Goal。
@MainActor
final class GoalVM: ObservableObject, SuperLog {
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = GoalTaskPlugin.logger
    public nonisolated static let emoji = "🇫🇯"

    /// 数据源提供器;注入点允许外部传入自定义 `GoalStateManager`(测试 / 多实例场景)。
    private let managerProvider: () -> GoalStateManager?

    /// 通知观察者持有者,懒加载绑定 `.goalDidChange`。
    private nonisolated let notificationObserverHolder = NotificationObserverHolder()

    @Published var currentConversationID: UUID?

    /// 当前对话的所有 Goal(每个携带自己的任务),按创建时间升序。
    /// 作为侧栏派生态与工具栏弹窗的单一数据源。
    @Published public var goals: [GoalListItem] = []

    /// 是否正在拉取 Goal 列表。
    @Published public var isLoading: Bool = false

    public init(managerProvider: @escaping () -> GoalStateManager? = { GoalTaskPlugin.currentManager() }) {
        self.managerProvider = managerProvider
    }

    // MARK: - 列表派生态(工具栏弹窗)

    /// 是否有活跃(非终态)Goal,供外部判断按钮启用状态 / 空态文案。
    public var hasActiveGoal: Bool {
        goals.contains { (item: GoalListItem) in item.goal.isTerminal == false }
    }

    // MARK: - 侧栏派生态(从 `goals` 推导单一活跃 Goal)

    /// 当前活跃的 Goal(首个 Goal)。单一目标模式下供侧栏展示;
    /// 是否真正可见由 `hasActiveWork` 结合状态与任务进度判定。
    public var activeGoal: GoalDisplayItem? {
        goals.first?.goal
    }

    /// 当前活跃 Goal 的 Tasks。
    public var activeTasks: [GoalTaskDisplayItem] {
        goals.first?.tasks ?? []
    }

    /// 是否有可见的 Goal(需要展示侧栏)。
    public var hasActiveWork: Bool {
        guard let goal = activeGoal else { return false }
        // 终态: completed, failed, skipped - 不显示
        switch goal.status {
        case .completed, .failed, .skipped:
            // 终态下检查是否还有进行中的 task
            return activeTasks.contains { task in
                switch task.status {
                case .completed, .failed, .skipped:
                    return false
                case .pending, .inProgress:
                    return true
                }
            }
        case .pending, .inProgress, .blocked:
            return true
        }
    }

    /// 进度信息,如 `"3/5"`(已完成 + 跳过 / 总数)。
    public var progressText: String {
        guard activeGoal != nil, !activeTasks.isEmpty else { return "" }
        let completed = activeTasks.filter { $0.status == .completed || $0.status == .skipped }.count
        return "\(completed)/\(activeTasks.count)"
    }

    // MARK: - 会话与刷新

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

    /// 移除 `.goalDidChange` 观察者。通常由视图 `onDisappear` 调用。
    public func removeObserver() {
        notificationObserverHolder.remove()
    }

    /// 刷新当前对话的 Goal 列表。
    ///
    /// - 无 `currentConversationID` 时清空 `goals` 并直接返回。
    /// - 无 `managerProvider` 时静默跳过(由调用方按需决定是否降级)。
    /// - 首次调用时懒加载绑定 `.goalDidChange`;当变更会话与当前会话匹配时自动 reload。
    /// - 每次 `await` 后用 `expectedID` 守卫,丢弃陈旧响应,避免快速切换残留。
    public func refresh() async {
        guard managerProvider() != nil else {
            if Self.verbose {
                Self.logger.info("\(Self.t)refresh 跳过:manager 不可用")
            }
            return
        }

        guard let conversationID = currentConversationID else {
            goals = []
            return
        }

        // 首次绑定 `.goalDidChange`(懒加载,后续 refresh 复用同一观察者)。
        if !notificationObserverHolder.hasObserver {
            let observer = NotificationCenter.default.addObserver(
                forName: .goalDidChange,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let changedCid = notification.userInfo?["conversationId"] as? String
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // 通知回调触发时,以触发瞬间的 cid 为期望值,丢弃陈旧响应。
                    if let changedCid,
                       changedCid == self.currentConversationID?.uuidString,
                       let expectedID = UUID(uuidString: changedCid) {
                        await self.reloadFromDB(expectedID: expectedID)
                    }
                }
            }
            notificationObserverHolder.set(observer)
        }

        isLoading = true
        await reloadFromDB(expectedID: conversationID)
        // 最后再做一次守卫:若本次 refresh 已被新切换覆盖,把 isLoading 留给最新 task 接管。
        guard currentConversationID == conversationID else { return }
        isLoading = false
    }

    /// 从数据库重新加载当前会话的 Goal 列表。
    ///
    /// - Parameter expectedID: 调用瞬间期望的会话 id。每次 `await` 之后都会与
    ///   `currentConversationID` 比对,若已被新切换覆盖则提前 return,丢弃陈旧响应。
    private func reloadFromDB(expectedID: UUID) async {
        guard let manager = managerProvider() else { return }

        let conversationId = expectedID.uuidString

        // 第 1 个 await:fetchGoals 可能在快速切换期间返回,先核对一次
        let fetchedGoals = await manager.fetchGoals(conversationId: conversationId)
        guard currentConversationID == expectedID else { return }

        // 逐个加载每个 goal 的任务(SwiftData 关系跨 ModelContext 不可靠,必须显式查询)。
        var items: [GoalListItem] = []
        for goal in fetchedGoals {
            // 第 2 个 await:fetchTasks 之前再核对一次
            guard currentConversationID == expectedID else { return }
            let tasks = await manager.fetchTasks(goalId: goal.id)
            guard currentConversationID == expectedID else { return }
            items.append(GoalListItem(
                goal: GoalDisplayItem(from: goal),
                tasks: tasks.map { GoalTaskDisplayItem(from: $0) }
            ))
        }
        goals = items

        if Self.verbose {
            Self.logger.info("\(Self.t)refresh 完成:conversation=\(conversationId) count=\(items.count)")
        }
    }
}
