import Testing
import Foundation
@testable import GoalTaskPlugin

/// 回归 #777：唯一的 Goal 因任务失败进入 failed 终态后，侧栏高度归零，
/// 而工具栏按钮又只按「Goal 数量 > 1」判定，导致这条被保留的失败记录
/// 在两个 UI 入口同时消失。
@MainActor
@Suite("Goal Failed Goal Visibility Tests")
struct GoalFailedGoalVisibilityTests {

    private func makeGoal(status: Goal.GoalStatus, id: String = "g1") -> GoalDisplayItem {
        GoalDisplayItem(from: Goal(
            id: id,
            conversationId: "c",
            title: "Goal",
            status: status
        ))
    }

    private func makeTask(status: GoalTask.TaskStatus, id: String = "t1") -> GoalTaskDisplayItem {
        GoalTaskDisplayItem(from: GoalTask(
            id: id,
            goalId: "g1",
            title: "Task",
            status: status
        ))
    }

    @Test("唯一的失败 Goal 且任务已结束时必须显示工具栏按钮")
    func testShownForSingleFailedGoalWithFailedTask() {
        let vm = GoalVM(managerProvider: { nil })
        vm.goals = [
            GoalListItem(goal: makeGoal(status: .failed), tasks: [makeTask(status: .failed)])
        ]

        // 侧栏不再呈现它，工具栏是查看这条保留记录的唯一入口。
        #expect(vm.hasActiveWork == false)
        #expect(vm.shouldShowToolbarButton == true)
    }

    @Test("唯一的失败 Goal 且没有任务时同样显示工具栏按钮")
    func testShownForSingleFailedGoalWithoutTasks() {
        let vm = GoalVM(managerProvider: { nil })
        vm.goals = [GoalListItem(goal: makeGoal(status: .failed), tasks: [])]

        #expect(vm.hasActiveWork == false)
        #expect(vm.shouldShowToolbarButton == true)
    }

    @Test("失败 Goal 仍有未结束任务时侧栏可见，按钮保持隐藏")
    func testHiddenForFailedGoalWithPendingTask() {
        let vm = GoalVM(managerProvider: { nil })
        vm.goals = [
            GoalListItem(goal: makeGoal(status: .failed), tasks: [makeTask(status: .pending)])
        ]

        #expect(vm.hasActiveWork == true)
        #expect(vm.shouldShowToolbarButton == false)
    }

    @Test("唯一的已完成 Goal 仍然隐藏按钮（自动删除路径不受影响）")
    func testHiddenForSingleCompletedGoal() {
        let vm = GoalVM(managerProvider: { nil })
        vm.goals = [
            GoalListItem(goal: makeGoal(status: .completed), tasks: [makeTask(status: .completed)])
        ]

        #expect(vm.hasActiveWork == false)
        #expect(vm.shouldShowToolbarButton == false)
    }
}