import Foundation

/// SidebarView 的视图模型。
///
/// 负责订阅 `GoalStateManager.fetchGoals` / `fetchTasks` 数据,监听
/// `.goalDidChange` 通知,以及维护「当前活跃 Goal + 其 Tasks」的展示状态。
/// `hasActiveWork` / `progressText` 等派生属性集中在此,避免视图层重复计算。
///
/// 标记 `public` 以兼容现有测试(`Tests/GoalStateManagerTests.swift`)。
@MainActor
final public class SidebarViewModel: ObservableObject {
    /// 当前活跃的 Goal(单一目标模式)
    @Published public var activeGoal: GoalDisplayItem?
    /// 当前活跃 Goal 的 Tasks
    @Published public var activeTasks: [GoalTaskDisplayItem] = []
    @Published public var isLoading: Bool = false

    public var currentConversationId: String?
    private nonisolated let notificationObserverHolder = NotificationObserverHolder()

    public init() {}

    /// 是否有可见的 Goal(需要展示侧栏)
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

    /// 获取进度信息
    public var progressText: String {
        guard let _ = activeGoal, !activeTasks.isEmpty else { return "" }
        let completed = activeTasks.filter { $0.status == .completed || $0.status == .skipped }.count
        return "\(completed)/\(activeTasks.count)"
    }

    /// 每次访问时动态获取 manager,避免缓存导致初始化时序问题
    @MainActor
    private var manager: GoalStateManager? {
        GoalTaskPlugin.currentManager()
    }

    public func removeObserver() {
        notificationObserverHolder.remove()
    }

    public func refresh(conversationId: String?) async {
        guard let conversationId else {
            activeGoal = nil
            activeTasks = []
            currentConversationId = nil
            isLoading = false
            return
        }

        currentConversationId = conversationId
        isLoading = true

        // 首次绑定通知
        if !notificationObserverHolder.hasObserver {
            let observer = NotificationCenter.default.addObserver(
                forName: .goalDidChange,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let changedCid = notification.userInfo?["conversationId"] as? String
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let changedCid, changedCid == self.currentConversationId {
                        await self.reloadFromDB()
                    }
                }
            }
            notificationObserverHolder.set(observer)
        }

        await reloadFromDB()
        isLoading = false
    }

    public func forceRefresh() async {
        await reloadFromDB()
    }

    private func reloadFromDB() async {
        guard let cid = currentConversationId,
              let manager
        else { return }

        let fetchedGoals = await manager.fetchGoals(conversationId: cid)

        // 查找最新的活跃 Goal(非终态)
        let activeGoalModel = fetchedGoals.first { goal in
            switch goal.status {
            case .completed, .failed, .skipped:
                return false
            case .pending, .inProgress, .blocked:
                return true
            }
        }

        if let goal = activeGoalModel {
            activeGoal = GoalDisplayItem(from: goal)
            let tasks = await manager.fetchTasks(goalId: goal.id)
            activeTasks = tasks.map { GoalTaskDisplayItem(from: $0) }
        } else {
            activeGoal = nil
            activeTasks = []
        }
    }
}