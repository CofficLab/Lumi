import Testing
import Foundation
import SwiftUI
@testable import GoalTaskPlugin

/// 覆盖展示映射与 ViewModel 派生态。
///
/// 这些都是纯值计算，出错时表现为 UI 显示错乱但不会崩溃，靠测试兜住映射表。
@MainActor
@Suite("Goal Display Item Tests")
struct GoalDisplayItemTests {

    private func makeGoal(
        status: Goal.GoalStatus,
        blockedReason: String? = nil,
        description: String? = nil
    ) -> Goal {
        Goal(
            conversationId: "c",
            title: "T",
            goalDescription: description,
            successCriteria: nil,
            status: status,
            blockedReason: blockedReason
        )
    }

    @Test("映射保留身份与状态字段")
    func testMappingPreservesFields() {
        let goal = Goal(
            conversationId: "c",
            title: "Title",
            goalDescription: "desc",
            successCriteria: nil,
            status: .blocked,
            blockedReason: "reason"
        )
        let item = GoalDisplayItem(from: goal)

        #expect(item.id == goal.id)
        #expect(item.title == "Title")
        #expect(item.status == .blocked)
        #expect(item.blockedReason == "reason")
        #expect(item.goalDescription == "desc")
    }

    @Test("终态判定只认 completed / failed / skipped")
    func testIsTerminal() {
        for status in [Goal.GoalStatus.completed, .failed, .skipped] {
            #expect(GoalDisplayItem(from: makeGoal(status: status)).isTerminal == true)
        }
        for status in [Goal.GoalStatus.pending, .inProgress, .blocked] {
            #expect(GoalDisplayItem(from: makeGoal(status: status)).isTerminal == false)
        }
    }

    @Test("每种状态都有唯一图标，不出现空串")
    func testStatusSystemImage() {
        let expected: [Goal.GoalStatus: String] = [
            .pending: "circle",
            .inProgress: "arrow.triangle.2.circlepath",
            .completed: "checkmark.circle.fill",
            .blocked: "exclamationmark.triangle.fill",
            .failed: "xmark.circle.fill",
            .skipped: "forward.circle",
        ]
        for (status, image) in expected {
            let actual = GoalDisplayItem(from: makeGoal(status: status)).statusSystemImage
            #expect(actual == image, "status \(status.rawValue) 期望 \(image)，实际 \(actual)")
            #expect(!actual.isEmpty)
        }
        // 图标不应重复，避免视觉上区分不出两个状态
        #expect(Set(expected.values).count == expected.count)
    }

    @Test("状态颜色随状态变化")
    func testStatusColorVariesByStatus() {
        let pending = GoalDisplayItem(from: makeGoal(status: .pending)).statusColor
        let completed = GoalDisplayItem(from: makeGoal(status: .completed)).statusColor
        let failed = GoalDisplayItem(from: makeGoal(status: .failed)).statusColor
        #expect(pending != completed)
        #expect(completed != failed)
    }
}

@MainActor
@Suite("Goal Task Display Item Tests")
struct GoalTaskDisplayItemTests {

    private func makeTask(
        status: GoalTask.TaskStatus,
        parallelGroup: String? = nil
    ) -> GoalTask {
        GoalTask(
            goalId: "g",
            title: "T",
            taskDescription: nil,
            executionContext: nil,
            status: status,
            order: 1,
            parallelGroup: parallelGroup
        )
    }

    @Test("映射保留任务身份、分组与状态")
    func testMappingPreservesFields() {
        let task = GoalTask(
            goalId: "g",
            title: "Task title",
            taskDescription: nil,
            executionContext: nil,
            status: .inProgress,
            order: 2,
            parallelGroup: "G"
        )
        let item = GoalTaskDisplayItem(from: task)

        #expect(item.id == task.id)
        #expect(item.title == "Task title")
        #expect(item.status == .inProgress)
        #expect(item.parallelGroup == "G")
    }

    @Test("每种任务状态都有唯一图标")
    func testStatusSystemImage() {
        let expected: [GoalTask.TaskStatus: String] = [
            .pending: "circle",
            .inProgress: "arrow.triangle.2.circlepath",
            .completed: "checkmark.circle.fill",
            .failed: "xmark.circle.fill",
            .skipped: "forward.circle",
        ]
        for (status, image) in expected {
            let actual = GoalTaskDisplayItem(from: makeTask(status: status)).statusSystemImage
            #expect(actual == image, "status \(status.rawValue) 期望 \(image)，实际 \(actual)")
        }
        #expect(Set(expected.values).count == expected.count)
    }

    @Test("颜色随状态变化，skipped 与 Goal 的灰色不同以示区分")
    func testStatusColor() {
        let completed = GoalTaskDisplayItem(from: makeTask(status: .completed)).statusColor
        let failed = GoalTaskDisplayItem(from: makeTask(status: .failed)).statusColor
        #expect(completed != failed)

        // Goal 的 skipped 是灰色，Task 的 skipped 是橙色，两者刻意不同
        let taskSkipped = GoalTaskDisplayItem(from: makeTask(status: .skipped)).statusColor
        let goalSkipped = GoalDisplayItem(from: Goal(conversationId: "c", title: "T", status: .skipped)).statusColor
        #expect(taskSkipped != goalSkipped)
    }
}

// MARK: - GoalVM

@MainActor
@Suite("Goal VM Tests")
struct GoalVMTests {

    private func makeManager() throws -> (manager: GoalStateManager, tempDir: URL) {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GoalVMTest-\(UUID().uuidString)")
        return (try GoalStateManager(databaseRootURL: tempDir), tempDir)
    }

    @Test("无当前会话时 refresh 清空列表")
    func testRefreshWithoutConversationClearsGoals() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vm = GoalVM(managerProvider: { manager })
        vm.goals = [GoalListItem(goal: GoalDisplayItem(from: Goal(conversationId: "x", title: "stale")), tasks: [])]
        #expect(vm.goals.count == 1)

        await vm.refresh()

        #expect(vm.goals.isEmpty)
        #expect(vm.isLoading == false)
    }

    @Test("当前会话切换到相同 ID 时跳过更新")
    func testUpdateCurrentConversationIDSkipsIdenticalValue() {
        let vm = GoalVM(managerProvider: { nil })
        let id = UUID()

        vm.updateCurrentConversationID(id)
        #expect(vm.currentConversationID == id)

        vm.updateCurrentConversationID(id)
        #expect(vm.currentConversationID == id)

        vm.updateCurrentConversationID(nil)
        #expect(vm.currentConversationID == nil)
    }

    @Test("manager 不可用时 refresh 静默跳过，不清空已有数据")
    func testRefreshSkipsWhenManagerUnavailable() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let conversationID = UUID(uuidString: "B8B8B8B8-1111-2222-3333-444444444444")!
        _ = try await manager.createGoal(
            conversationId: conversationID.uuidString,
            title: "Kept",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
        )

        let vm = GoalVM(managerProvider: { manager })
        vm.updateCurrentConversationID(conversationID)
        await vm.refresh()
        #expect(vm.goals.count == 1)

        // 数据源消失：保持原状，不把已有内容清成空态，也不进入 loading
        let broken = GoalVM(managerProvider: { nil })
        broken.goals = vm.goals
        broken.updateCurrentConversationID(conversationID)
        await broken.refresh()
        #expect(broken.goals.count == 1)
        #expect(broken.isLoading == false)
    }

    @Test("refresh 拉取目标会话的 Goal 与任务")
    func testRefreshLoadsGoalsAndTasks() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let conversationID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        _ = try await manager.createGoal(
            conversationId: conversationID.uuidString,
            title: "Loaded goal",
            description: nil,
            successCriteria: nil,
            tasks: [
                (title: "T1", description: nil, executionContext: nil, parallelGroup: nil),
                (title: "T2", description: nil, executionContext: nil, parallelGroup: "G"),
            ]
        )

        let vm = GoalVM(managerProvider: { manager })
        vm.updateCurrentConversationID(conversationID)
        await vm.refresh()

        #expect(vm.goals.count == 1)
        #expect(vm.activeGoal?.title == "Loaded goal")
        #expect(vm.activeTasks.count == 2)
        #expect(vm.activeTasks[0].status == .inProgress)
        #expect(vm.progressText == "0/2")
        #expect(vm.hasActiveGoal == true)
        #expect(vm.hasActiveWork == true)
        #expect(vm.isLoading == false)
    }

    @Test("空会话的派生态不报错，进度为空串")
    func testDerivedStateForEmptyConversation() {
        let vm = GoalVM(managerProvider: { nil })
        #expect(vm.activeGoal == nil)
        #expect(vm.activeTasks.isEmpty)
        #expect(vm.progressText == "")
        #expect(vm.hasActiveGoal == false)
        #expect(vm.hasActiveWork == false)
    }

    @Test("进度文本把已完成与已跳过都计入分子")
    func testProgressTextCountsCompletedAndSkipped() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let conversationID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let created = try await manager.createGoal(
            conversationId: conversationID.uuidString,
            title: "Progress goal",
            description: nil,
            successCriteria: nil,
            tasks: [
                (title: "A", description: nil, executionContext: nil, parallelGroup: nil),
                (title: "B", description: nil, executionContext: nil, parallelGroup: nil),
                (title: "C", description: nil, executionContext: nil, parallelGroup: nil),
                (title: "D", description: nil, executionContext: nil, parallelGroup: nil),
            ]
        )
        _ = try await manager.updateGoalTaskStatus(id: created.tasks[0].id, status: .completed)
        _ = try await manager.updateGoalTaskStatus(id: created.tasks[1].id, status: .skipped)
        _ = try await manager.updateGoalTaskStatus(id: created.tasks[2].id, status: .failed)

        let vm = GoalVM(managerProvider: { manager })
        vm.updateCurrentConversationID(conversationID)
        await vm.refresh()

        #expect(vm.activeTasks.count == 4)
        #expect(vm.progressText == "2/4")
    }

    @Test("Goal 终态但仍有进行中任务时侧栏仍可见")
    func testHasActiveWorkForTerminalGoalWithRunningTask() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let conversationID = UUID(uuidString: "99999999-8888-7777-6666-555555555555")!
        let created = try await manager.createGoal(
            conversationId: conversationID.uuidString,
            title: "Terminal with running task",
            description: nil,
            successCriteria: nil,
            tasks: [
                (title: "A", description: nil, executionContext: nil, parallelGroup: nil),
                (title: "B", description: nil, executionContext: nil, parallelGroup: nil),
            ]
        )
        // A 完成、B 保持 in_progress，然后把 Goal 手动标为 completed
        _ = try await manager.updateGoalTaskStatus(id: created.tasks[0].id, status: .completed)
        _ = try await manager.updateGoalTaskStatus(id: created.tasks[1].id, status: .inProgress)
        _ = try await manager.updateGoalStatus(id: created.goal.id, status: .completed)

        let vm = GoalVM(managerProvider: { manager })
        vm.updateCurrentConversationID(conversationID)
        await vm.refresh()

        #expect(vm.activeGoal?.status == .completed)
        #expect(vm.activeTasks.count == 2)
        #expect(vm.hasActiveWork == true)
    }

    @Test("Goal 终态且所有任务已结束时不显示侧栏")
    func testHasActiveWorkHiddenWhenEverythingDone() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let conversationID = UUID(uuidString: "CCCCCCCC-DDDD-EEEE-FFFF-000011112222")!
        let created = try await manager.createGoal(
            conversationId: conversationID.uuidString,
            title: "All done",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "A", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        _ = try await manager.updateGoalTaskStatus(id: created.tasks[0].id, status: .completed)
        _ = try await manager.updateGoalStatus(id: created.goal.id, status: .completed)

        let vm = GoalVM(managerProvider: { manager })
        vm.updateCurrentConversationID(conversationID)
        await vm.refresh()

        #expect(vm.hasActiveWork == false)
        #expect(vm.hasActiveGoal == false)
    }

    @Test("refreshIfCurrentConversation 只在会话匹配时刷新")
    func testRefreshIfCurrentConversationGuardsOnID() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let currentID = UUID(uuidString: "12121212-3434-5656-7878-909090909090")!
        let otherID = UUID(uuidString: "45454545-6767-8989-1010-111111111111")!

        _ = try await manager.createGoal(
            conversationId: currentID.uuidString,
            title: "Match",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
        )

        let vm = GoalVM(managerProvider: { manager })
        vm.updateCurrentConversationID(currentID)

        // 不匹配的会话不触发刷新，列表保持空
        vm.refreshIfCurrentConversation(otherID)
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(vm.goals.isEmpty)

        // 匹配的会话触发刷新；内部通过 Task 派发，轮询等待其落地
        vm.refreshIfCurrentConversation(currentID)
        for _ in 0..<40 where vm.goals.isEmpty {
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        #expect(vm.goals.count == 1)
    }
}

// MARK: - GoalChangeCenter / Observer

@MainActor
@Suite("Goal Change Observer Tests")
struct GoalChangeObserverTests {

    @Test("订阅者收到 notify 推送的会话 ID")
    func testObserverReceivesNotification() {
        let conversationID = UUID()
        var received: [UUID] = []
        let observer = GoalChangeObserver { received.append($0) }
        defer { observer.cancel() }

        GoalChangeCenter.shared.notify(conversationID: conversationID)

        #expect(received == [conversationID])
    }

    @Test("cancel 后不再收到通知")
    func testCancelStopsNotifications() {
        var received: [UUID] = []
        let observer = GoalChangeObserver { received.append($0) }

        GoalChangeCenter.shared.notify(conversationID: UUID())
        #expect(received.count == 1)

        observer.cancel()
        GoalChangeCenter.shared.notify(conversationID: UUID())
        #expect(received.count == 1)

        // 重复 cancel 是幂等的
        observer.cancel()
        GoalChangeCenter.shared.notify(conversationID: UUID())
        #expect(received.count == 1)
    }

    @Test("多个订阅者互不影响")
    func testMultipleObservers() {
        var first: [UUID] = []
        var second: [UUID] = []
        let a = GoalChangeObserver { first.append($0) }
        let b = GoalChangeObserver { second.append($0) }
        defer { b.cancel() }

        GoalChangeCenter.shared.notify(conversationID: UUID())
        #expect(first.count == 1)
        #expect(second.count == 1)

        a.cancel()
        GoalChangeCenter.shared.notify(conversationID: UUID())
        #expect(first.count == 1)
        #expect(second.count == 2)
    }
}
