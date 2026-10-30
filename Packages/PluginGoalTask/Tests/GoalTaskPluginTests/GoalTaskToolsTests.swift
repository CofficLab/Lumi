import KitAgentTool
import Foundation
import ProviderConversation
import Testing
@testable import GoalTaskPlugin

// serialized：与 GoalTaskV2Tests 共用 `GoalTaskPluginSupport._sharedManager` 静态状态。
extension SharedManagerSuite {

    @Suite("Goal Task Tools")
    @MainActor
    struct GoalTaskToolsTests {

        @MainActor
        private struct Harness {
            let manager: GoalStateManager
            let context: ToolExecutionContext
            let tempDir: URL

            func cleanup() {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }
        }

        @MainActor
        private func makeHarness() throws -> Harness {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("GoalTaskToolsTest-\(UUID().uuidString)")
            let manager = try GoalStateManager(databaseRootURL: tempDir)
            GoalTaskPluginSupport._sharedManager = manager

            let conversations = DefaultConversationManager()
            let conversationID = try conversations.createConversation(
                title: "Tools conversation",
                projectPath: nil,
                providerID: nil,
                modelName: nil
            )
            let context = ToolExecutionContext(jobID: "tools-job", conversationID: conversationID, turnID: UUID())
            return Harness(manager: manager, context: context, tempDir: tempDir)
        }

        // MARK: - add_tasks_to_goal

        @Test("add_tasks_to_goal 追加任务并回显 Goal ID 与任务列表")
        @MainActor
        func addTasksAppendsAndReports() async throws {
            let harness = try makeHarness()
            defer { harness.cleanup() }

            _ = try await CreateGoalV2Tool().executeResult(context: harness.context, arguments: [
                "title": ToolArgument("Grow the goal"),
                "tasks": ToolArgument([["title": "T1"]]),
            ])
            let goals = await harness.manager.fetchGoals(conversationId: harness.context.conversationID.uuidString)
            let goalId = try #require(goals.first?.id)

            let result = try await AddTasksToGoalV2Tool().executeResult(context: harness.context, arguments: [
                "goal_id": ToolArgument(goalId),
                "tasks": ToolArgument([
                    ["title": "T2", "description": "second"],
                    ["title": "T3", "parallelGroup": "B"],
                ]),
            ])

            #expect(result.isError == false)
            #expect(result.content.contains("Added 2 tasks"))
            #expect(result.content.contains("**Goal ID:**"))
            #expect(result.content.contains(goalId))
            #expect(result.content.contains("**T2**"))
            #expect(result.content.contains("**T3**"))

            let tasks = await harness.manager.fetchTasks(goalId: goalId)
            #expect(tasks.count == 3)
            #expect(tasks.map(\.title) == ["T1", "T2", "T3"])
            #expect(tasks[2].parallelGroup == "B")
        }

        @Test("add_tasks_to_goal 可省略 goal_id 自动解析唯一活跃 Goal")
        @MainActor
        func addTasksResolvesOmittedGoalId() async throws {
            let harness = try makeHarness()
            defer { harness.cleanup() }

            _ = try await CreateGoalV2Tool().executeResult(context: harness.context, arguments: [
                "title": ToolArgument("Auto resolve"),
                "tasks": ToolArgument([["title": "T1"]]),
            ])

            let result = try await AddTasksToGoalV2Tool().executeResult(context: harness.context, arguments: [
                "tasks": ToolArgument([["title": "Appended"]]),
            ])

            #expect(result.isError == false)
            #expect(result.content.contains("Added 1 tasks"))
            #expect(result.content.contains("**Appended**"))
        }

        @Test("add_tasks_to_goal 过滤缺少标题的任务")
        @MainActor
        func addTasksFiltersEntriesWithoutTitle() async throws {
            let harness = try makeHarness()
            defer { harness.cleanup() }

            _ = try await CreateGoalV2Tool().executeResult(context: harness.context, arguments: [
                "title": ToolArgument("Filter goal"),
                "tasks": ToolArgument([["title": "T1"]]),
            ])

            // 全部非法：返回错误提示且不写入
            let noValid = try await AddTasksToGoalV2Tool().executeResult(context: harness.context, arguments: [
                "tasks": ToolArgument([
                    ["description": "no title"],
                    ["title": "   "],
                ]),
            ])
            #expect(noValid.content.contains("no valid tasks"))

            // 混合：只写入合法项
            let mixed = try await AddTasksToGoalV2Tool().executeResult(context: harness.context, arguments: [
                "tasks": ToolArgument([
                    ["description": "dropped"],
                    ["title": "Kept"],
                ]),
            ])
            #expect(mixed.content.contains("Added 1 tasks"))
            #expect(mixed.content.contains("**Kept**"))
        }

        @Test("add_tasks_to_goal 目标不存在时返回可恢复错误")
        @MainActor
        func addTasksReportsUnknownGoal() async throws {
            let harness = try makeHarness()
            defer { harness.cleanup() }

            let result = try await AddTasksToGoalV2Tool().executeResult(context: harness.context, arguments: [
                "goal_id": ToolArgument("no-such-goal"),
                "tasks": ToolArgument([["title": "T"]]),
            ])

            #expect(result.content.contains("goal not found"))
            #expect(result.content.contains("Available goals in this conversation"))
        }

        @Test("add_tasks_to_goal 在 Goal 已满时报告失败而不是假装成功")
        @MainActor
        func addTasksReportsFullGoal() async throws {
            let harness = try makeHarness()
            defer { harness.cleanup() }

            let goals = await harness.manager.fetchGoals(conversationId: harness.context.conversationID.uuidString)
            let goalId: String
            if let existing = goals.first {
                goalId = existing.id
            } else {
                _ = try await CreateGoalV2Tool().executeResult(context: harness.context, arguments: [
                    "title": ToolArgument("Full goal"),
                    "tasks": ToolArgument((1...GoalStateManager.maxTasksPerGoal).map { ["title": "T\($0)"] }),
                ])
                goalId = try #require(await harness.manager.fetchGoals(conversationId: harness.context.conversationID.uuidString).first?.id)
            }

            let result = try await AddTasksToGoalV2Tool().executeResult(context: harness.context, arguments: [
                "goal_id": ToolArgument(goalId),
                "tasks": ToolArgument([["title": "Overflow"]]),
            ])

            #expect(result.content.contains("failed to add tasks"))
            #expect(await harness.manager.fetchTasks(goalId: goalId).count == GoalStateManager.maxTasksPerGoal)
        }

        @Test("add_tasks_to_goal 在 manager 未就绪时给出明确提示")
        func addTasksWithoutManager() async throws {
            GoalTaskPluginSupport._sharedManager = nil
            defer { GoalTaskPluginSupport._sharedManager = nil }

            let output = try await AddTasksToGoalV2Tool().execute(arguments: [
                "tasks": ToolArgument([["title": "T"]]),
            ])
            #expect(output == "Error: goal task manager is not initialized")
        }

        // MARK: - update_task_status

        @Test("update_task_status 更新任务并回显 Goal 新状态")
        @MainActor
        func updateTaskStatusReportsGoalState() async throws {
            let harness = try makeHarness()
            defer { harness.cleanup() }

            _ = try await CreateGoalV2Tool().executeResult(context: harness.context, arguments: [
                "title": ToolArgument("Update goal"),
                "tasks": ToolArgument([["title": "T1"], ["title": "T2"]]),
            ])
            let goals = await harness.manager.fetchGoals(conversationId: harness.context.conversationID.uuidString)
            let goal = try #require(goals.first)
            let tasks = await harness.manager.fetchTasks(goalId: goal.id)

            let result = try await UpdateTaskStatusV2Tool().execute(arguments: [
                "task_id": ToolArgument(tasks[0].id),
                "status": ToolArgument("completed"),
                "result": ToolArgument("shipped"),
            ])

            #expect(result.contains("Task **T1** updated to **completed**"))
            #expect(result.contains("status: **in_progress**"))

            let refreshed = try #require(await harness.manager.fetchGoal(id: goal.id))
            #expect(refreshed.status == .inProgress)
            #expect(await harness.manager.fetchTasks(goalId: goal.id)[0].result == "shipped")
        }

        @Test("update_task_status 拒绝非法状态值")
        func updateTaskStatusRejectsInvalidStatus() async throws {
            GoalTaskPluginSupport._sharedManager = nil
            defer { GoalTaskPluginSupport._sharedManager = nil }

            let output = try await UpdateTaskStatusV2Tool().execute(arguments: [
                "task_id": ToolArgument("t"),
                "status": ToolArgument("not_a_status"),
            ])
            #expect(output == "Error: invalid status")

            // 缺少 status 同样是无效
            let missing = try await UpdateTaskStatusV2Tool().execute(arguments: [
                "task_id": ToolArgument("t"),
            ])
            #expect(missing == "Error: invalid status")
        }

        @Test("update_task_status 任务推进后重置续跑预算")
        @MainActor
        func updateTaskStatusResetsContinuationBudget() async throws {
            let harness = try makeHarness()
            defer { harness.cleanup() }

            let conversationId = harness.context.conversationID.uuidString
            _ = try await CreateGoalV2Tool().executeResult(context: harness.context, arguments: [
                "title": ToolArgument("Budget goal"),
                "tasks": ToolArgument([["title": "T1"]]),
            ])
            let goal = try #require(await harness.manager.fetchGoals(conversationId: conversationId).first)
            let task = try #require(await harness.manager.fetchTasks(goalId: goal.id).first)

            // 耗尽续跑预算
            for _ in 0..<GoalStateManager.maxAutomaticContinuations {
                _ = await harness.manager.incrementContinuationCount(conversationId: conversationId)
            }
            #expect(await harness.manager.incrementContinuationCount(conversationId: conversationId) == nil)

            _ = try await UpdateTaskStatusV2Tool().execute(arguments: [
                "task_id": ToolArgument(task.id),
                "status": ToolArgument("completed"),
            ])

            // 任务推进即视为正常工作，预算恢复
            #expect(await harness.manager.incrementContinuationCount(conversationId: conversationId) == 1)
            #expect(await harness.manager.incrementAskUserAnswerCount(conversationId: conversationId) == 1)
        }

        @Test("update_task_status 任务不存在时返回失败文案")
        @MainActor
        func updateTaskStatusReportsMissingTask() async throws {
            let harness = try makeHarness()
            defer { harness.cleanup() }

            let output = try await UpdateTaskStatusV2Tool().execute(arguments: [
                "task_id": ToolArgument("missing-task-id"),
                "status": ToolArgument("completed"),
            ])
            #expect(output.contains("failed to update task"))
            #expect(output.contains("Task not found"))
        }

        // MARK: - get_goal_progress

        @Test("get_goal_progress 汇总各状态计数与百分比")
        @MainActor
        func getProgressSummarizesStatuses() async throws {
            let harness = try makeHarness()
            defer { harness.cleanup() }

            let conversationId = harness.context.conversationID.uuidString
            _ = try await CreateGoalV2Tool().executeResult(context: harness.context, arguments: [
                "title": ToolArgument("Progress goal"),
                "tasks": ToolArgument([["title": "A"], ["title": "B"], ["title": "C"], ["title": "D"]]),
            ])
            let goal = try #require(await harness.manager.fetchGoals(conversationId: conversationId).first)
            let tasks = await harness.manager.fetchTasks(goalId: goal.id)

            _ = try await UpdateTaskStatusV2Tool().execute(arguments: [
                "task_id": ToolArgument(tasks[0].id), "status": ToolArgument("completed"),
            ])
            _ = try await UpdateTaskStatusV2Tool().execute(arguments: [
                "task_id": ToolArgument(tasks[1].id), "status": ToolArgument("skipped"),
            ])
            _ = try await UpdateTaskStatusV2Tool().execute(arguments: [
                "task_id": ToolArgument(tasks[2].id), "status": ToolArgument("failed"),
            ])

            let progress = try await GetGoalProgressV2Tool().executeResult(context: harness.context, arguments: [
                "goal_id": ToolArgument(goal.id),
            ])

            #expect(progress.isError == false)
            #expect(progress.content.contains("**Progress:** 2/4 (50%)"))
            #expect(progress.content.contains("- Completed: 1"))
            #expect(progress.content.contains("- Skipped: 1"))
            #expect(progress.content.contains("- Failed: 1"))
            // 每行任务带状态图标与 rawValue
            #expect(progress.content.contains("✅ A [completed]"))
            #expect(progress.content.contains("⏭️ B [skipped]"))
            #expect(progress.content.contains("❌ C [failed]"))
            #expect(progress.content.contains("⏳ D [pending]"))
        }

        @Test("get_goal_progress 在 manager 未就绪时给出明确提示")
        func getProgressWithoutManager() async throws {
            GoalTaskPluginSupport._sharedManager = nil
            defer { GoalTaskPluginSupport._sharedManager = nil }

            let output = try await GetGoalProgressV2Tool().execute(arguments: [:])
            #expect(output == "Error: goal task manager is not initialized")
        }

        @Test("update_goal_status 支持 blocked 并记录原因")
        @MainActor
        func updateGoalStatusBlocked() async throws {
            let harness = try makeHarness()
            defer { harness.cleanup() }

            _ = try await CreateGoalV2Tool().executeResult(context: harness.context, arguments: [
                "title": ToolArgument("Blocked goal"),
                "tasks": ToolArgument([["title": "T1"]]),
            ])

            let result = try await UpdateGoalStatusV2Tool().executeResult(context: harness.context, arguments: [
                "status": ToolArgument("blocked"),
                "blocked_reason": ToolArgument("missing credentials"),
            ])
            #expect(result.isError == false)
            #expect(result.content.contains("updated to **blocked**"))

            let goal = try #require(await harness.manager.fetchGoals(conversationId: harness.context.conversationID.uuidString).first)
            #expect(goal.status == .blocked)
            #expect(goal.blockedReason == "missing credentials")
        }

        @Test("update_goal_status 拒绝非法状态值")
        func updateGoalStatusRejectsInvalidStatus() async throws {
            GoalTaskPluginSupport._sharedManager = nil
            defer { GoalTaskPluginSupport._sharedManager = nil }

            let output = try await UpdateGoalStatusV2Tool().execute(arguments: [
                "goal_id": ToolArgument("g"),
                "status": ToolArgument("not_a_status"),
            ])
            #expect(output.contains("invalid status"))
        }
    }
}

// MARK: - GoalTaskToolSupport

extension SharedManagerSuite {

    @Suite("Goal Task Tool Support Tests")
    @MainActor
    struct GoalTaskToolSupportTests {

        @Test("string 去掉首尾空白；纯空白串归一为空串而非 nil")
        func testStringTrimming() {
            let arguments: [String: ToolArgument] = [
                "padded": ToolArgument("  value  "),
                "blank": ToolArgument("   "),
                "wrongType": ToolArgument(42),
            ]
            #expect(GoalTaskToolSupport.string(arguments, "padded") == "value")
            // 保留为 ""，调用方用 isEmpty 判断空值，不用 nil 判断
            #expect(GoalTaskToolSupport.string(arguments, "blank") == "")
            #expect(GoalTaskToolSupport.string(arguments, "wrongType") == nil)
            #expect(GoalTaskToolSupport.string(arguments, "missing") == nil)
        }

        @Test("taskInputs 丢弃缺少标题或标题为空的项")
        func testTaskInputsFiltering() {
            let inputs = GoalTaskToolSupport.taskInputs([
                ["title": "Valid", "description": "d", "executionContext": "c", "parallelGroup": "g"],
                ["description": "no title"],
                ["title": "   "],
                ["title": 7],
            ])
            #expect(inputs.count == 1)
            #expect(inputs.first?.title == "Valid")
            #expect(inputs.first?.description == "d")
            #expect(inputs.first?.executionContext == "c")
            #expect(inputs.first?.parallelGroup == "g")
        }

        @Test("taskInputs 对 nil 与非字典数组返回空")
        func testTaskInputsNonArray() {
            #expect(GoalTaskToolSupport.taskInputs(nil).isEmpty)
            #expect(GoalTaskToolSupport.taskInputs("nope").isEmpty)
            #expect(GoalTaskToolSupport.taskInputs(123).isEmpty)
            #expect(GoalTaskToolSupport.taskInputs([1, 2, 3]).isEmpty)
        }

        @Test("taskSchema 默认不带 maxItems，显式传入时附加上限")
        func testTaskSchema() {
            let base = GoalTaskToolSupport.taskSchema()
            #expect(base["type"] as? String == "array")
            #expect(base["minItems"] as? Int == 1)
            #expect(base["maxItems"] == nil)

            let properties = (base["items"] as? [String: Any])?["properties"] as? [String: Any]
            #expect(properties?.keys.contains("title") == true)
            #expect(properties?.keys.contains("description") == true)
            #expect(properties?.keys.contains("executionContext") == true)
            #expect(properties?.keys.contains("parallelGroup") == true)
            #expect((base["items"] as? [String: Any])?["required"] as? [String] == ["title"])

            let capped = GoalTaskToolSupport.taskSchema(maxItems: 20)
            #expect(capped["maxItems"] as? Int == 20)
        }

        @Test("normalize 忽略大小写与首尾空白")
        func testNormalize() {
            #expect(GoalTaskToolSupport.normalize("  Hello World  ") == "hello world")
        }

        @Test("goalListText 输出每行的 id、标题与状态")
        func testGoalListText() {
            let goals = [
                Goal(conversationId: "c", title: "First", status: .inProgress),
                Goal(conversationId: "c", title: "Second", status: .completed),
            ]
            let text = GoalTaskToolSupport.goalListText(goals)
            #expect(text.contains("- [\(goals[0].id)] **First** (in_progress)"))
            #expect(text.contains("- [\(goals[1].id)] **Second** (completed)"))
        }
    }
}
