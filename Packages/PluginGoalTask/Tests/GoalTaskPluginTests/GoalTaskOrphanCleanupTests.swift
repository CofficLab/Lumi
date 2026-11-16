import Foundation
import SwiftData
import Testing
@testable import GoalTaskPlugin

/// 回归 #815：Goal 完成后的自动清理（`deleteAllGoals`）必须连带删除其全部 Task。
///
/// Task 创建时只写字符串 `goalId`、未建立 SwiftData 对象关系，`Goal.tasks` 的
/// `.cascade` 命中不到这些 Task，Goal 删除后 Task 永久残留孤儿，描述与执行上下文
/// 持续占盘。修复双管齐下：
/// 1. 创建 / 追加 / fork 时建立 `task.goal` 关系，让 `.cascade` 按设计生效；
/// 2. `deleteAllGoals` 再显式按 `goalId` 删除，连历史遗留的未链接孤儿一并清掉。
///
/// 关系断言走独立保活的 `ModelContext`：返回值的 `.tasks` / `.goal` 需要活上下文
/// 才能 fault，createGoal 内部的上下文在返回后已释放，直接读关系不可靠。
@MainActor
@Suite("GoalTask 孤儿 Task 清理（#815）", .serialized)
struct GoalTaskOrphanCleanupTests {
    private func makeManager() throws -> (GoalStateManager, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoalTaskOrphan-\(UUID().uuidString)", isDirectory: true)
        return (try GoalStateManager(databaseRootURL: directory), directory)
    }

    private func makeGoal(
        in manager: GoalStateManager,
        conversationID: String,
        taskCount: Int
    ) async throws -> (goalID: String, taskIDs: [String]) {
        let tasks: [(title: String, description: String?, executionContext: String?, parallelGroup: String?)] =
            (0..<taskCount).map { index in
                (title: "Task \(index)", description: nil, executionContext: nil, parallelGroup: nil)
            }
        let result = try await manager.createGoal(
            conversationId: conversationID,
            title: "Goal",
            description: nil,
            successCriteria: nil,
            tasks: tasks
        )
        return (result.goal.id, result.tasks.map(\.id))
    }

    @Test("createGoal 建立 Task→Goal 关系，使 .cascade 可命中（**回归 #815**）")
    func testCreateGoalLinksTasksForCascade() async throws {
        let (manager, directory) = try makeManager()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID().uuidString
        let (goalID, taskIDs) = try await makeGoal(in: manager, conversationID: conversationID, taskCount: 2)

        let container = try GoalStateManager.makeContainer(databaseRootURL: directory)
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Goal>(predicate: #Predicate<Goal> { $0.id == goalID })
        let goal = try #require(context.fetch(descriptor).first)

        #expect(goal.tasks.count == 2, "Task 必须挂到 Goal.tasks，否则 cascade 删除命中不到")
        #expect(Set(goal.tasks.map(\.id)) == Set(taskIDs))
        #expect(goal.tasks.allSatisfy { $0.goal?.id == goalID }, "每个 Task 的 inverse 关系必须指回 Goal")
    }

    @Test("deleteAllGoals 清除 createGoal 产生的全部 Task（**回归 #815**）")
    func testDeleteAllGoalsRemovesCreatedTasks() async throws {
        let (manager, directory) = try makeManager()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID().uuidString
        let (goalID, _) = try await makeGoal(in: manager, conversationID: conversationID, taskCount: 3)
        #expect(await manager.fetchTasks(goalId: goalID).count == 3)

        try await manager.deleteAllGoals(conversationId: conversationID)

        #expect(await manager.fetchGoals(conversationId: conversationID).isEmpty)
        #expect(await manager.fetchTasks(goalId: goalID).isEmpty, "Goal 删除后不得残留 Task 孤儿")
    }

    @Test("deleteAllGoals 清除追加（addTasksToGoal）的 Task（**回归 #815**）")
    func testDeleteAllGoalsRemovesAppendedTasks() async throws {
        let (manager, directory) = try makeManager()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID().uuidString
        let (goalID, _) = try await makeGoal(in: manager, conversationID: conversationID, taskCount: 1)
        _ = try await manager.addTasksToGoal(goalId: goalID, tasks: [
            (title: "Appended A", description: nil, executionContext: nil, parallelGroup: nil),
            (title: "Appended B", description: nil, executionContext: nil, parallelGroup: nil),
        ])
        #expect(await manager.fetchTasks(goalId: goalID).count == 3)

        try await manager.deleteAllGoals(conversationId: conversationID)

        #expect(await manager.fetchTasks(goalId: goalID).isEmpty, "追加的 Task 同样不得绕过清理")
    }

    @Test("deleteAllGoals 清除 fork 副本的 Task，且不影响源会话（**回归 #815**）")
    func testDeleteAllGoalsRemovesForkedTasks() async throws {
        let (manager, directory) = try makeManager()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceConversation = UUID().uuidString
        let targetConversation = UUID().uuidString
        let (sourceGoalID, _) = try await makeGoal(in: manager, conversationID: sourceConversation, taskCount: 2)

        let forked = try await manager.forkGoal(id: sourceGoalID, into: targetConversation)
        let forkedGoalID = forked.goal.id
        #expect(await manager.fetchTasks(goalId: forkedGoalID).count == 2)

        try await manager.deleteAllGoals(conversationId: targetConversation)

        #expect(await manager.fetchTasks(goalId: forkedGoalID).isEmpty, "fork 副本的 Task 不得绕过清理")
        #expect(await manager.fetchGoals(conversationId: targetConversation).isEmpty)
        // 源会话的 Task 不受目标会话清理影响。
        #expect(await manager.fetchTasks(goalId: sourceGoalID).count == 2)
    }

    @Test("deleteAllGoals 显式按 goalId 清除未链接的历史孤儿 Task（**回归 #815**）")
    func testDeleteAllGoalsRemovesUnlinkedLegacyOrphan() async throws {
        let (manager, directory) = try makeManager()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID().uuidString
        let (goalID, _) = try await makeGoal(in: manager, conversationID: conversationID, taskCount: 1)

        // 模拟历史遗留数据：只写 goalId、不建立对象关系的孤儿 Task。
        // 用独立容器写入后立即释放，再让 manager 清理，验证按 goalId 的显式删除
        // 不依赖 .cascade（孤儿未链接，cascade 命中不到）。
        do {
            let container = try GoalStateManager.makeContainer(databaseRootURL: directory)
            let context = ModelContext(container)
            let orphan = GoalTask(goalId: goalID, title: "Legacy orphan")
            context.insert(orphan)
            try context.save()
        }
        // 前置条件：孤儿确实落库且对 manager 可见（linked 1 + orphan 1）。
        #expect(await manager.fetchTasks(goalId: goalID).count == 2)

        try await manager.deleteAllGoals(conversationId: conversationID)

        #expect(await manager.fetchTasks(goalId: goalID).isEmpty, "未链接孤儿也必须按 goalId 一并清除")
        #expect(await manager.fetchGoals(conversationId: conversationID).isEmpty)
    }
}