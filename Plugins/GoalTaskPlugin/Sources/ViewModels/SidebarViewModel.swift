import Foundation

/// SidebarView 的视图模型。
///
/// 负责订阅 `GoalStateManager.fetchGoals` / `fetchTasks` 数据,监听
/// `.goalDidChange` 通知,以及维护「当前活跃 Goal + 其 Tasks」的展示状态。
/// `hasActiveWork` / `progressText` 等派生属性集中在此,避免视图层重复计算。
///
/// 标记 `public` 以兼容现有测试(`Tests/GoalStateManagerTests.swift`)。
///
/// 并发安全:每次加载都用 `expectedCid` 守卫,在 `await` 边界之后重新比对
/// `currentConversationId`,丢弃已被新切换覆盖的陈旧响应,避免快速切换
/// 对话时显示上一个对话的残留 Goal。
@MainActor
final public class SidebarViewModel: ObservableObject {
    /// 当前活跃的 Goal(单一目标模式)
    @Published public var activeGoal: GoalDisplayItem?
    /// 当前活跃 Goal 的 Tasks
    @Published public var activeTasks: [GoalTaskDisplayItem] = []
    @Published public var isLoading: Bool = false

    public var currentConversationId: String?
    private nonisolated let notificationObserverHolder = NotificationObserverHolder()

    /// 数据源提供器,默认从全局 `GoalTaskPlugin.currentManager()` 取。
    /// 注入点允许外部传入自定义 `GoalStateManager`(测试 / 多实例场景)。
    private let managerProvider: () -> GoalStateManager?

    public init(managerProvider: @escaping () -> GoalStateManager? = { GoalTaskPlugin.currentManager() }) {
        self.managerProvider = managerProvider
    }

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

    /// 获取数据源;通过 `managerProvider` 注入,避免硬编码全局单例。
    @MainActor
    private var manager: GoalStateManager? {
        managerProvider()
    }

    public func removeObserver() {
        notificationObserverHolder.remove()
    }

    public func refresh(conversationId: String?) async {
        guard let conversationId else {
            // 没有 cid 时直接清空，避免后续通知误匹配
            activeGoal = nil
            activeTasks = []
            currentConversationId = nil
            isLoading = false
            return
        }

        // 提前清空 + 同步更新 cid，让 UI 立即摆脱上一个对话的残留数据，
        // 并让 .goalDidChange 通知回调立刻按新 cid 做匹配。
        activeGoal = nil
        activeTasks = []
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
                        // 通知回调触发时，以触发瞬间的 cid 为期望值，丢弃陈旧响应
                        await self.reloadFromDB(expectedCid: changedCid)
                    }
                }
            }
            notificationObserverHolder.set(observer)
        }

        await reloadFromDB(expectedCid: conversationId)
        // 最后再做一次守卫：如果这次 refresh 已经被新切换覆盖，就不该清掉 isLoading，
        // 把状态留给最新的 task 接管。
        guard currentConversationId == conversationId else { return }
        isLoading = false
    }

    public func forceRefresh() async {
        // 手动刷新使用当前 cid 作为期望值
        await reloadFromDB(expectedCid: currentConversationId)
    }

    /// 从数据库重新加载当前 cid 的活跃 Goal 与 Tasks。
    ///
    /// - Parameter expectedCid: 调用瞬间期望的会话 id。每次 await 之后都会与
    ///   `currentConversationId` 比对，若已被新切换覆盖则提前 return，丢弃陈旧响应，
    ///   避免在快速切换对话时显示上一个对话的残留数据。
    private func reloadFromDB(expectedCid: String?) async {
        guard let expectedCid,
              let manager
        else { return }

        // 第 1 个 await：fetchGoals 可能在快速切换期间返回，先核对一次
        let fetchedGoals = await manager.fetchGoals(conversationId: expectedCid)
        guard currentConversationId == expectedCid else { return }

        // 查找最新的活跃 Goal（非终态）
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
            // 第 2 个 await：fetchTasks 之前再核对一次
            let tasks = await manager.fetchTasks(goalId: goal.id)
            guard currentConversationId == expectedCid else { return }
            activeTasks = tasks.map { GoalTaskDisplayItem(from: $0) }
        } else {
            activeGoal = nil
            activeTasks = []
        }
    }
}