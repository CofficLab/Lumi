import Testing
import Foundation
@testable import GoalTaskPlugin

@Suite("Goal State Manager Tests")
struct GoalStateManagerTests {
    
    @Test("Create goal with tasks")
    func testCreateGoal() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GoalTaskTest-\(UUID().uuidString)")
        let manager = GoalStateManager(databaseRootURL: tempDir)
        
        let result = try await manager.createGoal(
            conversationId: "test-conv-1",
            title: "Build auth system",
            description: "Test goal",
            successCriteria: "Users can login",
            tasks: [
                (title: "Task 1", description: "First task", executionContext: nil, parallelGroup: "A"),
                (title: "Task 2", description: "Second task", executionContext: nil, parallelGroup: "A"),
                (title: "Task 3", description: "Third task", executionContext: nil, parallelGroup: "B")
            ]
        )
        
        #expect(result.goal.title == "Build auth system")
        #expect(result.tasks.count == 3)
        #expect(result.goal.status == .inProgress)
        #expect(result.tasks[0].status == .inProgress)
        #expect(result.tasks[1].parallelGroup == "A")
    }
    
    @Test("Update task status auto-derives goal status")
    func testUpdateTaskStatusDerivesGoalStatus() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GoalTaskTest-\(UUID().uuidString)")
        let manager = GoalStateManager(databaseRootURL: tempDir)
        
        let result = try await manager.createGoal(
            conversationId: "test-conv-2",
            title: "Simple goal",
            description: nil,
            successCriteria: nil,
            tasks: [
                (title: "Only task", description: nil, executionContext: nil, parallelGroup: nil)
            ]
        )
        
        let updateResult = try await manager.updateGoalTaskStatus(
            id: result.tasks[0].id,
            status: .completed,
            result: "Done"
        )
        
        #expect(updateResult.task.status == .completed)
        #expect(updateResult.goal.status == .completed)
        #expect(updateResult.goal.completedAt != nil)
    }
    
    @Test("Update goal status to blocked")
    func testUpdateGoalStatusBlocked() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GoalTaskTest-\(UUID().uuidString)")
        let manager = GoalStateManager(databaseRootURL: tempDir)
        
        let result = try await manager.createGoal(
            conversationId: "test-conv-3",
            title: "Blocked goal",
            description: nil,
            successCriteria: nil,
            tasks: [
                (title: "Task", description: nil, executionContext: nil, parallelGroup: nil)
            ]
        )
        
        let updated = try await manager.updateGoalStatus(
            id: result.goal.id,
            status: .blocked,
            blockedReason: "Missing API key"
        )
        
        #expect(updated.status == .blocked)
        #expect(updated.blockedReason == "Missing API key")
    }
    
    @Test("Fetch goals by conversation")
    func testFetchGoals() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GoalTaskTest-\(UUID().uuidString)")
        let manager = GoalStateManager(databaseRootURL: tempDir)
        
        _ = try await manager.createGoal(
            conversationId: "test-conv-4",
            title: "Goal A",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "Task", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        
        _ = try await manager.createGoal(
            conversationId: "test-conv-4",
            title: "Goal B",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "Task", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        
        let goals = await manager.fetchGoals(conversationId: "test-conv-4")
        #expect(goals.count == 2)
    }

    /// 回归测试：create 之后立即 fetch 必须读到刚写入的 Goal。
    /// 历史上 Sidebar 读取 0 的根因是"工具写入的 manager 实例与 Sidebar 读取的实例不同"
    /// （指向不同数据库文件）。这里用同一 manager 覆盖核心路径：写入后立即查询必须非空。
    @Test("Create then immediately fetch returns the goal")
    func testCreateThenFetchImmediately() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GoalTaskTest-\(UUID().uuidString)")
        let manager = GoalStateManager(databaseRootURL: tempDir)

        let cid = "577967FE-1812-4278-8752-D0E72ED9B567"
        _ = try await manager.createGoal(
            conversationId: cid,
            title: "添加「项目仪表盘」功能",
            description: nil,
            successCriteria: nil,
            tasks: (1...6).map { _ in (title: "Task", description: nil, executionContext: nil, parallelGroup: nil) }
        )

        let fetched = await manager.fetchGoals(conversationId: cid)
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "添加「项目仪表盘」功能")
    }

    /// 回归测试：所有 Goal 到达终态后，侧栏应判定为无可展示工作（hasActiveWork == false），
    /// 即使数据尚未被 TurnFinishedHook 清理。对应「完成时 UI 不消失」的修复。
    @MainActor
    @Test("Sidebar hides when all goals reach terminal state")
    func testSidebarHidesWhenAllDone() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GoalTaskTest-\(UUID().uuidString)")
        let manager = GoalStateManager(databaseRootURL: tempDir)
        let cid = "conv-done"

        // 一个 Goal，其唯一 Task 先建为 in_progress
        let created = try await manager.createGoal(
            conversationId: cid,
            title: "Done goal",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "Only task", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        // 完成 Task → Goal 自动推导为 completed
        _ = try await manager.updateGoalTaskStatus(id: created.tasks[0].id, status: .completed, result: nil)

        let vm = SidebarViewModel()
        let goals = await manager.fetchGoals(conversationId: cid)
        vm.activeGoal = goals.first.map { GoalDisplayItem(from: $0) }
        if let goal = goals.first {
            vm.activeTasks = (await manager.fetchTasks(goalId: goal.id)).map { GoalTaskDisplayItem(from: $0) }
        }

        // 数据仍在 DB（尚未被 hook 清理），但全部到终态 → 应隐藏
        #expect(vm.activeGoal != nil)
        #expect(vm.hasActiveWork == false)
    }

    /// 回归测试：存在未完成工作时侧栏保持可见。
    @MainActor
    @Test("Sidebar visible when work is in progress")
    func testSidebarVisibleWhenInProgress() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GoalTaskTest-\(UUID().uuidString)")
        let manager = GoalStateManager(databaseRootURL: tempDir)
        let cid = "conv-active"

        let created = try await manager.createGoal(
            conversationId: cid,
            title: "Active goal",
            description: nil,
            successCriteria: nil,
            tasks: [
                (title: "T1", description: nil, executionContext: nil, parallelGroup: nil),
                (title: "T2", description: nil, executionContext: nil, parallelGroup: nil)
            ]
        )
        // 只完成第一个 Task，第二个仍 pending
        _ = try await manager.updateGoalTaskStatus(id: created.tasks[0].id, status: .completed, result: nil)

        let vm = SidebarViewModel()
        vm.activeGoal = GoalDisplayItem(from: created.goal)
        let tasks = await manager.fetchTasks(goalId: created.goal.id)
        vm.activeTasks = tasks.map { GoalTaskDisplayItem(from: $0) }

        #expect(vm.hasActiveWork == true)
    }
}