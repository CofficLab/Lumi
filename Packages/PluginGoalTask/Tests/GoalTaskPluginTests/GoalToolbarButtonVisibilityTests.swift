import Testing
import Foundation
import SwiftUI
@testable import GoalTaskPlugin

/// 工具栏 Goal 按钮的可见性判定。
///
/// 工具栏弹窗的价值在于「一屏看全所有 Goal」,而侧栏只展示首个 Goal。
/// 因此只有一个 Goal 时按钮属于重复信息,应当隐藏;只有存在多个 Goal 时
/// 侧栏装不下,按钮才成为查看全量列表的唯一入口。
@MainActor
@Suite("Goal Toolbar Button Visibility Tests")
struct GoalToolbarButtonVisibilityTests {

    /// 构造一个 Goal 展示项。
    private func makeGoal(
        status: Goal.GoalStatus = .inProgress,
        id: String = "g1"
    ) -> GoalDisplayItem {
        GoalDisplayItem(from: Goal(
            id: id,
            conversationId: "c",
            title: "Goal",
            status: status
        ))
    }

    /// 构造一个任务展示项。
    private func makeTask(
        status: GoalTask.TaskStatus = .pending,
        id: String = "t1"
    ) -> GoalTaskDisplayItem {
        GoalTaskDisplayItem(from: GoalTask(
            id: id,
            goalId: "g1",
            title: "Task",
            status: status
        ))
    }

    @Test("没有 Goal 时不显示按钮")
    func testHiddenWithoutGoals() {
        let vm = GoalVM(managerProvider: { nil })
        #expect(vm.shouldShowToolbarButton == false)
    }

    @Test("只有一个活跃 Goal 时隐藏按钮")
    func testHiddenForSingleActiveGoal() {
        let vm = GoalVM(managerProvider: { nil })
        vm.goals = [
            GoalListItem(goal: makeGoal(status: .inProgress), tasks: [makeTask(status: .pending)])
        ]

        #expect(vm.shouldShowToolbarButton == false)
    }

    @Test("只有一个终态 Goal 且任务全部结束时同样隐藏按钮")
    func testHiddenForSingleFinishedGoal() {
        let vm = GoalVM(managerProvider: { nil })
        vm.goals = [
            GoalListItem(
                goal: makeGoal(status: .completed),
                tasks: [makeTask(status: .completed)]
            )
        ]

        // 前置条件:侧栏已收起,但按钮仍属重复信息,不应顶回来。
        #expect(vm.hasActiveWork == false)
        #expect(vm.shouldShowToolbarButton == false)
    }

    @Test("多个 Goal 时保留按钮")
    func testShownForMultipleGoals() {
        let vm = GoalVM(managerProvider: { nil })
        vm.goals = [
            GoalListItem(goal: makeGoal(status: .inProgress, id: "g1"), tasks: [makeTask(status: .pending)]),
            GoalListItem(goal: makeGoal(status: .pending, id: "g2"), tasks: []),
        ]

        #expect(vm.shouldShowToolbarButton == true)
    }

    @Test("多个 Goal 时即使侧栏没展示第二个也保留按钮")
    func testShownForMultipleGoalsWhenSidebarCollapsed() {
        let vm = GoalVM(managerProvider: { nil })
        vm.goals = [
            GoalListItem(
                goal: makeGoal(status: .completed, id: "g1"),
                tasks: [makeTask(status: .completed)]
            ),
            GoalListItem(goal: makeGoal(status: .pending, id: "g2"), tasks: []),
        ]

        // 前置条件:侧栏只展示首个 Goal,第二个 Goal 只能通过弹窗看到。
        #expect(vm.hasActiveWork == false)
        #expect(vm.shouldShowToolbarButton == true)
    }
}
