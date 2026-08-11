import Foundation
import LumiKernel

/// Goal 工具栏按钮的视图模型。
///
/// 拉取当前会话的 Goal 列表(每个 Goal 携带其 Tasks),并以 `GoalListItem`
/// 的形态暴露给 `GoalToolbarButton` / `GoalPopoverContent`。
/// 当前没有订阅 `.goalDidChange` 通知——弹窗按需在打开时调用 `refresh()`,
/// 后续若需要实时刷新,可复用 `NotificationObserverHolder`。
///
/// 标记 `internal`,因为仅在模块内被工具栏相关视图消费;若日后对外暴露,
/// 升级为 `public` 并加访问控制注解。
@MainActor
final class GoalToolbarViewModel: ObservableObject {
    /// 当前对话的所有 Goal(每个携带自己的任务),按创建时间升序。
    @Published public var goals: [GoalListItem] = []
    @Published public var isLoading: Bool = false

    private let kernel: LumiKernel

    private var manager: GoalStateManager? {
        GoalTaskPlugin.currentManager()
    }

    /// 是否有活跃(非终态)Goal,供外部判断。
    public var hasActiveGoal: Bool {
        goals.contains { (item: GoalListItem) in item.goal.isTerminal == false }
    }

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    func refresh() async {
        guard let manager else { return }

        guard let conversations = kernel.conversations,
              let conversationID = conversations.selectedConversationID ?? conversations.conversations.first?.id else {
            goals = []
            return
        }

        await loadGoals(conversationId: conversationID.uuidString, manager: manager)
    }

    private func loadGoals(conversationId: String, manager: GoalStateManager) async {
        // 每次点击都重新拉取最新列表(用户可能在外部新增了 goal)。
        isLoading = true

        let fetchedGoals = await manager.fetchGoals(conversationId: conversationId)

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
        isLoading = false
    }
}