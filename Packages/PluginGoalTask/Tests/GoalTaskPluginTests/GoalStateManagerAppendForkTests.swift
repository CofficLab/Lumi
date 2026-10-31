import Testing
import Foundation
@testable import GoalTaskPlugin

/// 覆盖 `GoalStateManager` 中此前未被触达的分支：
/// 追加任务（容量截断 / order 续接）、Goal 分叉、错误分支文案。
@MainActor
@Suite("Goal State Manager Append / Fork Tests")
struct GoalStateManagerAppendForkTests {

    private func makeManager() throws -> (manager: GoalStateManager, tempDir: URL) {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GoalTaskAppendForkTest-\(UUID().uuidString)")
        return (try GoalStateManager(databaseRootURL: tempDir), tempDir)
    }

    // MARK: - addTasksToGoal

    @Test("追加任务时 order 从现有最大值续接，且不改动已有任务状态")
    func testAddTasksContinuesOrder() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let created = try await manager.createGoal(
            conversationId: "append-order",
            title: "Append order goal",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "First", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        #expect(created.tasks[0].order == 1)

        let appended = try await manager.addTasksToGoal(
            goalId: created.goal.id,
            tasks: [
                (title: "Second", description: "d2", executionContext: "ctx2", parallelGroup: "G"),
                (title: "Third", description: nil, executionContext: nil, parallelGroup: nil),
            ]
        )

        #expect(appended.count == 2)
        #expect(appended[0].order == 2)
        #expect(appended[1].order == 3)
        #expect(appended[0].taskDescription == "d2")
        #expect(appended[0].executionContext == "ctx2")
        #expect(appended[0].parallelGroup == "G")

        // 追加的任务不应自动变成 in_progress，只有首任务在创建时是 in_progress
        #expect(appended.allSatisfy { $0.status == .pending })

        let all = await manager.fetchTasks(goalId: created.goal.id)
        #expect(all.count == 3)
        #expect(all.map(\.order) == [1, 2, 3])
        #expect(all[0].status == .inProgress)
    }

    @Test("追加任务时 Goal 已满则抛 tooManyTasks，不静默丢弃")
    func testAddTasksThrowsWhenGoalAlreadyFull() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 先塞满到上限
        let seed = try await manager.createGoal(
            conversationId: "append-cap",
            title: "Capacity goal",
            description: nil,
            successCriteria: nil,
            tasks: (1...GoalStateManager.maxTasksPerGoal).map {
                (title: "T\($0)", description: nil, executionContext: nil, parallelGroup: nil)
            }
        )
        #expect(seed.tasks.count == GoalStateManager.maxTasksPerGoal)

        // 再追加 3 个：一个都放不下，直接报错而不是假装成功
        do {
            _ = try await manager.addTasksToGoal(
                goalId: seed.goal.id,
                tasks: (1...3).map {
                    (title: "Extra\($0)", description: nil, executionContext: nil, parallelGroup: nil)
                }
            )
            Issue.record("expected tooManyTasks")
        } catch let error as GoalStateError {
            #expect(error.errorDescription == "Too many tasks (max: \(GoalStateManager.maxTasksPerGoal))")
        }

        // 报错不应写入任何任务
        #expect(await manager.fetchTasks(goalId: seed.goal.id).count == GoalStateManager.maxTasksPerGoal)
    }

    @Test("追加任务在只剩部分容量时只写入能放下的部分")
    func testAddTasksWritesPartialBatch() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let seed = try await manager.createGoal(
            conversationId: "append-partial",
            title: "Partial goal",
            description: nil,
            successCriteria: nil,
            tasks: (1...(GoalStateManager.maxTasksPerGoal - 2)).map {
                (title: "T\($0)", description: nil, executionContext: nil, parallelGroup: nil)
            }
        )

        let appended = try await manager.addTasksToGoal(
            goalId: seed.goal.id,
            tasks: (1...5).map {
                (title: "Extra\($0)", description: nil, executionContext: nil, parallelGroup: nil)
            }
        )

        #expect(appended.count == 2)
        #expect(appended[0].order == GoalStateManager.maxTasksPerGoal - 1)
        #expect(appended[1].order == GoalStateManager.maxTasksPerGoal)
    }

    @Test("向不存在的 Goal 追加任务抛 goalNotFound")
    func testAddTasksToMissingGoalThrows() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await #expect(throws: GoalStateError.self) {
            try await manager.addTasksToGoal(
                goalId: "missing-goal",
                tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
            )
        }

        do {
            _ = try await manager.addTasksToGoal(
                goalId: "missing-goal",
                tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
            )
            Issue.record("expected goalNotFound")
        } catch let error as GoalStateError {
            #expect(error.errorDescription == "Goal not found: missing-goal")
        }
    }

    // MARK: - Goal capacity

    @Test("单会话 Goal 数量达到上限后拒绝继续创建")
    func testCreateGoalRejectsWhenConversationFull() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cid = "full-conversation"
        for index in 1...GoalStateManager.maxGoalsPerConversation {
            _ = try await manager.createGoal(
                conversationId: cid,
                title: "Goal \(index)",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
            )
        }
        #expect(await manager.fetchGoals(conversationId: cid).count == GoalStateManager.maxGoalsPerConversation)

        do {
            _ = try await manager.createGoal(
                conversationId: cid,
                title: "Overflow",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
            )
            Issue.record("expected tooManyGoals")
        } catch let error as GoalStateError {
            #expect(error.errorDescription == "Too many goals (max: \(GoalStateManager.maxGoalsPerConversation))")
        }

        // 另一个会话不受影响
        _ = try await manager.createGoal(
            conversationId: "other-conversation",
            title: "Fresh",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        #expect(await manager.fetchGoals(conversationId: "other-conversation").count == 1)
    }

    // MARK: - Fork

    @Test("fork 复制 Goal 与任务，并把源 Goal 标记为 skipped")
    func testForkCopiesGoalAndTasks() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let source = try await manager.createGoal(
            conversationId: "fork-source",
            title: "Forkable goal",
            description: "desc",
            successCriteria: "criteria",
            tasks: [
                (title: "Done", description: nil, executionContext: nil, parallelGroup: nil),
                (title: "Todo", description: nil, executionContext: nil, parallelGroup: "P"),
            ]
        )
        // 让首个任务完成，验证任务状态/结果会被一并复制
        _ = try await manager.updateGoalTaskStatus(
            id: source.tasks[0].id,
            status: .completed,
            result: "done result"
        )

        let targetConversation = "fork-target"
        let forked = try await manager.forkGoal(id: source.goal.id, into: targetConversation)

        #expect(forked.id != source.goal.id)
        #expect(forked.conversationId == targetConversation)
        #expect(forked.title == "Forkable goal")
        #expect(forked.goalDescription == "desc")
        #expect(forked.successCriteria == "criteria")
        // 源 Goal 当时仍在进行中，副本保持同状态
        #expect(forked.status == .inProgress)
        #expect(forked.completedAt == nil)

        let forkedTasks = await manager.fetchTasks(goalId: forked.id)
        #expect(forkedTasks.count == 2)
        #expect(forkedTasks[0].title == "Done")
        #expect(forkedTasks[0].status == .completed)
        #expect(forkedTasks[0].result == "done result")
        #expect(forkedTasks[1].status == .pending)
        #expect(forkedTasks[1].parallelGroup == "P")
        // 副本的 id 与源任务不同，order 保持
        #expect(forkedTasks.allSatisfy { $0.goalId == forked.id })
        #expect(forkedTasks[0].id != source.tasks[0].id)
        #expect(forkedTasks.map(\.order) == [1, 2])

        // 源 Goal 必须退出活跃集合，避免两个会话争抢同一目标
        let refreshedSource = await manager.fetchGoal(id: source.goal.id)
        #expect(refreshedSource?.status == .skipped)
        #expect(refreshedSource?.isTerminal == true)

        // 源会话的任务不应被删除
        #expect(await manager.fetchTasks(goalId: source.goal.id).count == 2)
    }

    @Test("fork 终态 Goal 时副本重置为 pending，不继承完成时间")
    func testForkResetsTerminalStatusToPending() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let source = try await manager.createGoal(
            conversationId: "fork-terminal",
            title: "Finished goal",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        _ = try await manager.updateGoalStatus(id: source.goal.id, status: .completed)

        let forked = try await manager.forkGoal(id: source.goal.id, into: "fork-terminal-target")

        #expect(forked.status == .pending)
        #expect(forked.completedAt == nil)
    }

    @Test("目标会话已有活跃 Goal 时拒绝 fork")
    func testForkRejectsWhenTargetHasActiveGoal() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let source = try await manager.createGoal(
            conversationId: "fork-busy-source",
            title: "Source",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        let blocker = try await manager.createGoal(
            conversationId: "fork-busy-target",
            title: "Blocking goal",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        #expect(blocker.goal.status == .inProgress)

        do {
            _ = try await manager.forkGoal(id: source.goal.id, into: "fork-busy-target")
            Issue.record("expected activeGoalAlreadyExists")
        } catch let error as GoalStateError {
            #expect(error.errorDescription == "This conversation already has an unfinished goal: Blocking goal (\(blocker.goal.id))")
        }

        // 失败时不写入任何副本
        #expect(await manager.fetchGoals(conversationId: "fork-busy-target").count == 1)
    }

    @Test("目标会话只有终态 Goal 时允许 fork")
    func testForkAllowedWhenTargetOnlyHasTerminalGoals() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let source = try await manager.createGoal(
            conversationId: "fork-term-source",
            title: "Source",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        let stale = try await manager.createGoal(
            conversationId: "fork-term-target",
            title: "Stale",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        _ = try await manager.updateGoalStatus(id: stale.goal.id, status: .failed)

        let forked = try await manager.forkGoal(id: source.goal.id, into: "fork-term-target")
        #expect(forked.title == "Source")
        #expect(await manager.fetchGoals(conversationId: "fork-term-target").count == 2)
    }

    @Test("fork 不存在的 Goal 抛 goalNotFound")
    func testForkMissingGoalThrows() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        do {
            _ = try await manager.forkGoal(id: "nope", into: "fork-missing")
            Issue.record("expected goalNotFound")
        } catch let error as GoalStateError {
            #expect(error.errorDescription == "Goal not found: nope")
        }
    }

    // MARK: - Error descriptions

    @Test("GoalStateError 每个 case 都有面向用户的文案")
    func testGoalStateErrorDescriptions() {
        #expect(GoalStateError.tooManyGoals(max: 10).errorDescription == "Too many goals (max: 10)")
        #expect(GoalStateError.tooManyTasks(max: 50).errorDescription == "Too many tasks (max: 50)")
        #expect(GoalStateError.goalNotFound(id: "g1").errorDescription == "Goal not found: g1")
        #expect(GoalStateError.taskNotFound(id: "t1").errorDescription == "Task not found: t1")
        #expect(
            GoalStateError.activeGoalAlreadyExists(title: "T", goalId: "g9")
                .errorDescription == "This conversation already has an unfinished goal: T (g9)"
        )
    }

    // MARK: - updateGoalTaskStatus error paths

    @Test("更新不存在的任务抛 taskNotFound")
    func testUpdateMissingTaskThrows() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        do {
            _ = try await manager.updateGoalTaskStatus(id: "missing-task", status: .completed)
            Issue.record("expected taskNotFound")
        } catch let error as GoalStateError {
            #expect(error.errorDescription == "Task not found: missing-task")
        }
    }

    @Test("任务标记 failed 时记录 errorMessage，Goal 不被自动覆盖")
    func testUpdateTaskFailureRecordsErrorAndKeepsGoalStatus() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let created = try await manager.createGoal(
            conversationId: "task-failed",
            title: "Goal",
            description: nil,
            successCriteria: nil,
            tasks: [
                (title: "A", description: nil, executionContext: nil, parallelGroup: nil),
                (title: "B", description: nil, executionContext: nil, parallelGroup: nil),
            ]
        )

        let updated = try await manager.updateGoalTaskStatus(
            id: created.tasks[1].id,
            status: .failed,
            errorMessage: "boom"
        )

        #expect(updated.task.status == .failed)
        #expect(updated.task.errorMessage == "boom")
        #expect(updated.task.completedAt == nil)
        // 一个进行中 + 一个失败 => Goal 仍为 in_progress
        #expect(updated.goal.status == .inProgress)
    }

    @Test("全部任务失败时 Goal 推导为 failed")
    func testGoalDerivesFailedWhenAllTasksFail() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let created = try await manager.createGoal(
            conversationId: "all-failed",
            title: "Goal",
            description: nil,
            successCriteria: nil,
            tasks: [
                (title: "A", description: nil, executionContext: nil, parallelGroup: nil),
                (title: "B", description: nil, executionContext: nil, parallelGroup: nil),
            ]
        )
        _ = try await manager.updateGoalTaskStatus(id: created.tasks[0].id, status: .failed)
        _ = try await manager.updateGoalTaskStatus(id: created.tasks[1].id, status: .failed)

        let goal = await manager.fetchGoal(id: created.goal.id)
        #expect(goal?.status == .failed)
    }

    @Test("LLM 手动标记 blocked 后任务推进不再自动改写 Goal 状态")
    func testManualBlockedStatusIsNotOverwritten() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let created = try await manager.createGoal(
            conversationId: "blocked-guard",
            title: "Goal",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "A", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        _ = try await manager.updateGoalStatus(id: created.goal.id, status: .blocked, blockedReason: "need key")
        _ = try await manager.updateGoalTaskStatus(id: created.tasks[0].id, status: .completed)

        let goal = await manager.fetchGoal(id: created.goal.id)
        #expect(goal?.status == .blocked)
        #expect(goal?.blockedReason == "need key")
    }

    @Test("手动标记 failed 的 Goal 同样不被任务推进覆盖")
    func testManualFailedStatusIsNotOverwritten() async throws {
        let (manager, tempDir) = try makeManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let created = try await manager.createGoal(
            conversationId: "failed-guard",
            title: "Goal",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "A", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        _ = try await manager.updateGoalStatus(id: created.goal.id, status: .failed, failureReason: "manual")
        _ = try await manager.updateGoalTaskStatus(id: created.tasks[0].id, status: .completed)

        let goal = await manager.fetchGoal(id: created.goal.id)
        #expect(goal?.status == .failed)
        #expect(goal?.failureReason == "manual")
    }
}

// MARK: - GoalProgressSummary

@Suite("Goal Progress Summary Tests")
struct GoalProgressSummaryTests {

    @Test("完成百分比按已完成 + 已跳过计算")
    func testCompletionPercent() {
        let summary = GoalProgressSummary(
            goalId: "g",
            goalTitle: "Goal",
            goalStatus: .inProgress,
            totalTasks: 4,
            completedTasks: 2,
            inProgressTasks: 1,
            pendingTasks: 1,
            failedTasks: 0,
            skippedTasks: 1
        )
        #expect(summary.completionPercent == 75)
    }

    @Test("总任务为 0 时完成百分比为 0 且不算全部完成")
    func testEmptySummary() {
        let summary = GoalProgressSummary(
            goalId: "g",
            goalTitle: "Goal",
            goalStatus: .pending,
            totalTasks: 0,
            completedTasks: 0,
            inProgressTasks: 0,
            pendingTasks: 0,
            failedTasks: 0,
            skippedTasks: 0
        )
        #expect(summary.completionPercent == 0)
        #expect(summary.isAllDone == false)
    }

    @Test("没有 pending / in_progress 任务即视为全部结束")
    func testIsAllDone() {
        func summary(pending: Int, inProgress: Int, failed: Int) -> GoalProgressSummary {
            GoalProgressSummary(
                goalId: "g",
                goalTitle: "Goal",
                goalStatus: .inProgress,
                totalTasks: 3,
                completedTasks: 1,
                inProgressTasks: inProgress,
                pendingTasks: pending,
                failedTasks: failed,
                skippedTasks: 0
            )
        }
        #expect(summary(pending: 0, inProgress: 0, failed: 0).isAllDone == true)
        #expect(summary(pending: 0, inProgress: 0, failed: 2).isAllDone == true)
        #expect(summary(pending: 1, inProgress: 0, failed: 0).isAllDone == false)
        #expect(summary(pending: 0, inProgress: 1, failed: 0).isAllDone == false)
    }
}
