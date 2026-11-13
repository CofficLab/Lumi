import Foundation
import KitAgentTool
import ProviderConversation
import Testing
@testable import GoalTaskPlugin

// serialized：这些测试共享 GoalTaskPluginSupport._sharedManager 静态状态，
// 并行执行会互相覆盖（清空）manager。
extension SharedManagerSuite {

    @Suite("GoalTask V2")
    @MainActor
    struct GoalTaskV2Tests {
        @Test @MainActor func preservesPluginIdentityAndPolicy() {
            let plugin = GoalTaskPlugin()
            #expect(plugin.id == "com.coffic.lumi.plugin.goal-task")
            #expect(plugin.order == 91)
            #expect(plugin.metadata.policy == .alwaysOn)
            #expect(plugin.metadata.category == .chat)
        }

        @Test func preservesLegacyToolNamesAndRequiredArguments() {
            let tools = [
                CreateGoalV2Tool().name,
                AddTasksToGoalV2Tool().name,
                GetGoalProgressV2Tool().name,
                UpdateGoalStatusV2Tool().name,
                UpdateTaskStatusV2Tool().name,
            ]
            #expect(tools == ["create_goal", "add_tasks_to_goal", "get_goal_progress", "update_goal_status", "update_task_status"])
            #expect(CreateGoalV2Tool().inputSchema["required"] as? [String] == ["title", "tasks"])
            #expect(UpdateTaskStatusV2Tool().inputSchema["required"] as? [String] == ["task_id", "status"])
        }

        @Test("create_goal 使用 Agent 回合会话而非 UI 当前选中会话")
        @MainActor
        func createGoalUsesExecutionConversation() async throws {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("GoalTaskContextTest-\(UUID().uuidString)")
            let manager = try GoalStateManager(databaseRootURL: tempDir)
            GoalTaskPluginSupport._sharedManager = manager
            defer { GoalTaskPluginSupport._sharedManager = nil }

            let conversations = DefaultConversationManager()
            let executionConversationID = try conversations.createConversation(
                title: "Conversation 1",
                projectPath: nil,
                providerID: nil,
                modelName: nil
            )
            let selectedConversationID = try conversations.createConversation(
                title: "Conversation 2",
                projectPath: nil,
                providerID: nil,
                modelName: nil
            )
            #expect(conversations.selectedConversationID == selectedConversationID)

            let context = ToolExecutionContext(
                jobID: "goal-job",
                conversationID: executionConversationID,
                turnID: UUID()
            )
            let arguments: [String: ToolArgument] = [
                "title": ToolArgument("Goal from execution conversation"),
                "tasks": ToolArgument([
                    ["title": "Task 1"]
                ]),
            ]

            let result = try await CreateGoalV2Tool(conversations: conversations).executeResult(
                context: context,
                arguments: arguments
            )
            let executionGoals = await manager.fetchGoals(conversationId: executionConversationID.uuidString)
            let selectedGoals = await manager.fetchGoals(conversationId: selectedConversationID.uuidString)

            #expect(result.isError == false)
            #expect(executionGoals.count == 1)
            #expect(executionGoals.first?.title == "Goal from execution conversation")
            #expect(selectedGoals.isEmpty)
        }

        @Test("Goal 会话 Bridge 收到切换后的新会话 ID")
        @MainActor
        func goalConversationBridgeUsesUpdatedSelection() throws {
            let conversations = DefaultConversationManager()
            let firstID = try conversations.createConversation(
                title: "Conversation 1",
                projectPath: nil,
                providerID: nil,
                modelName: nil
            )
            let secondID = try conversations.createConversation(
                title: "Conversation 2",
                projectPath: nil,
                providerID: nil,
                modelName: nil
            )
            conversations.selectConversation(id: firstID)
            let bridge = GoalTaskConversationBridge(conversations)

            conversations.selectConversation(id: secondID)

            #expect(bridge.selectedConversationID == secondID)
        }

        @Test("create_goal 没有执行上下文时拒绝写入")
        func createGoalRejectsContextlessExecution() async {
            do {
                _ = try await CreateGoalV2Tool().execute(arguments: [:])
                Issue.record("create_goal should require an Agent execution context")
            } catch {
                #expect(String(describing: error).contains("execution context"))
            }
        }

        // MARK: - goal_id resolution（修复：创建时不输出 id / 错误不可恢复）

        /// 搭建临时 manager + 会话上下文，返回可用于 executeResult 的 context。
        @MainActor
        private func makeHarness() throws -> (manager: GoalStateManager, context: ToolExecutionContext, tempDir: URL) {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("GoalTaskResolveTest-\(UUID().uuidString)")
            let manager = try GoalStateManager(databaseRootURL: tempDir)
            GoalTaskPluginSupport._sharedManager = manager

            let conversations = DefaultConversationManager()
            let conversationID = try conversations.createConversation(
                title: "Resolve conversation",
                projectPath: nil,
                providerID: nil,
                modelName: nil
            )
            let context = ToolExecutionContext(jobID: "resolve-job", conversationID: conversationID, turnID: UUID())
            return (manager, context, tempDir)
        }

        @Test("create_goal 返回 Goal ID，后续工具可用它")
        @MainActor
        func createGoalExposesGoalId() async throws {
            let (_, context, tempDir) = try makeHarness()
            defer { GoalTaskPluginSupport._sharedManager = nil; try? FileManager.default.removeItem(at: tempDir) }

            let result = try await CreateGoalV2Tool().executeResult(context: context, arguments: [
                "title": ToolArgument("Expose goal id"),
                "tasks": ToolArgument([["title": "T1"]]),
            ])
            let goals = await GoalTaskPluginSupport._sharedManager!.fetchGoals(conversationId: context.conversationID.uuidString)
            let goalId = try #require(goals.first?.id)

            #expect(result.isError == false)
            #expect(result.content.contains("**Goal ID:**"))
            #expect(result.content.contains(goalId))
        }

        @Test("update_goal_status 可以用标题解析 goal_id（id 丢失时的恢复路径）")
        @MainActor
        func goalIdResolvesByTitle() async throws {
            let (_, context, tempDir) = try makeHarness()
            defer { GoalTaskPluginSupport._sharedManager = nil; try? FileManager.default.removeItem(at: tempDir) }

            let created = try await CreateGoalV2Tool().executeResult(context: context, arguments: [
                "title": ToolArgument("Title Lookup Goal"),
                "tasks": ToolArgument([["title": "T1"]]),
            ])
            #expect(created.isError == false)

            // 故意不传 goal_id，改传标题
            let updated = try await UpdateGoalStatusV2Tool().executeResult(context: context, arguments: [
                "goal_id": ToolArgument("title lookup goal"), // 大小写不敏感
                "status": ToolArgument("completed"),
            ])
            #expect(updated.isError == false)
            #expect(updated.content.contains("updated to **completed**"))
        }

        @Test("省略 goal_id 时自动解析会话内唯一活跃 goal")
        @MainActor
        func omittedGoalIdResolvesActiveGoal() async throws {
            let (_, context, tempDir) = try makeHarness()
            defer { GoalTaskPluginSupport._sharedManager = nil; try? FileManager.default.removeItem(at: tempDir) }

            _ = try await CreateGoalV2Tool().executeResult(context: context, arguments: [
                "title": ToolArgument("Only Active Goal"),
                "tasks": ToolArgument([["title": "T1"]]),
            ])

            // 完全不传 goal_id —— 自动解析唯一活跃 goal
            let progress = try await GetGoalProgressV2Tool().executeResult(context: context, arguments: [:])
            #expect(progress.isError == false)
            #expect(progress.content.contains("Only Active Goal"))
            #expect(progress.content.contains("**Goal ID:**"))
        }

        @Test("goal not found 错误附本会话候选列表（可恢复）")
        @MainActor
        func unknownGoalIdListsCandidates() async throws {
            let (_, context, tempDir) = try makeHarness()
            defer { GoalTaskPluginSupport._sharedManager = nil; try? FileManager.default.removeItem(at: tempDir) }

            _ = try await CreateGoalV2Tool().executeResult(context: context, arguments: [
                "title": ToolArgument("Candidate Listing Goal"),
                "tasks": ToolArgument([["title": "T1"]]),
            ])

            // 回归 #769：失败必须抛出，错误消息里仍要带候选 goal 让模型能自我恢复。
            do {
                _ = try await GetGoalProgressV2Tool().executeResult(context: context, arguments: [
                    "goal_id": ToolArgument("nonexistent-goal-xyz"),
                ])
                Issue.record("Expected get_goal_progress to throw for an unknown goal")
            } catch {
                #expect(error.localizedDescription.contains("goal not found"))
                #expect(error.localizedDescription.contains("Available goals in this conversation"))
                #expect(error.localizedDescription.contains("Candidate Listing Goal"))
            }
        }

        /// 回归 #189：带会话上下文的工具只能用精确 goal_id 解析本会话的 Goal。
        /// 另一个会话的精确 ID 必须 goal not found，且不得读取 / 改写 / 追加对方数据。
        @Test("精确 goal_id 不得跨会话解析（回归 #189）")
        @MainActor
        func testPreciseGoalIdCannotCrossConversations() async throws {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("GoalTaskCrossConv-\(UUID().uuidString)")
            let manager = try GoalStateManager(databaseRootURL: tempDir)
            GoalTaskPluginSupport._sharedManager = manager
            defer { GoalTaskPluginSupport._sharedManager = nil; try? FileManager.default.removeItem(at: tempDir) }

            let conversations = DefaultConversationManager()
            let convA = try conversations.createConversation(title: "A", projectPath: nil, providerID: nil, modelName: nil)
            let convB = try conversations.createConversation(title: "B", projectPath: nil, providerID: nil, modelName: nil)
            let contextA = ToolExecutionContext(jobID: "job-a", conversationID: convA, turnID: UUID())
            let contextB = ToolExecutionContext(jobID: "job-b", conversationID: convB, turnID: UUID())

            let created = try await CreateGoalV2Tool().executeResult(context: contextA, arguments: [
                "title": ToolArgument("Goal in A"),
                "tasks": ToolArgument([["title": "T1"]]),
            ])
            #expect(created.isError == false)
            let goalId = try #require(await manager.fetchGoals(conversationId: convA.uuidString).first?.id)
            let tasksBefore = await manager.fetchTasks(goalId: goalId).count

            // 会话 B 用 A 的精确 goal_id 读进度：必须 goal not found。
            do {
                _ = try await GetGoalProgressV2Tool().executeResult(context: contextB, arguments: ["goal_id": ToolArgument(goalId)])
                Issue.record("get_goal_progress should not resolve another conversation's goal")
            } catch {
                #expect(error.localizedDescription.contains("goal not found"))
            }

            // 会话 B 用 A 的精确 goal_id 改状态：必须失败。
            do {
                _ = try await UpdateGoalStatusV2Tool().executeResult(context: contextB, arguments: ["goal_id": ToolArgument(goalId), "status": ToolArgument("completed")])
                Issue.record("update_goal_status should not modify another conversation's goal")
            } catch {
                #expect(error.localizedDescription.contains("goal not found"))
            }

            // 会话 B 用 A 的精确 goal_id 追加任务：必须失败。
            do {
                _ = try await AddTasksToGoalV2Tool().executeResult(context: contextB, arguments: ["goal_id": ToolArgument(goalId), "tasks": ToolArgument([["title": "Injected"]])])
                Issue.record("add_tasks_to_goal should not append to another conversation's goal")
            } catch {
                #expect(error.localizedDescription.contains("goal not found"))
            }

            // A 的 Goal 状态与任务数必须原样保留。
            let goalA = try #require(await manager.fetchGoals(conversationId: convA.uuidString).first)
            #expect(goalA.status == .inProgress)
            #expect(await manager.fetchTasks(goalId: goalId).count == tasksBefore)
        }

        /// 正向对照：精确 goal_id 在本会话内仍可解析，终态 Goal 也不例外，
        /// 确保 #189 的会话隔离没有误伤合法的精确 ID 用法。
        @Test("精确 goal_id 在本会话内仍可解析（含终态 Goal）")
        @MainActor
        func testPreciseGoalIdResolvesWithinSameConversation() async throws {
            let (manager, context, tempDir) = try makeHarness()
            defer { GoalTaskPluginSupport._sharedManager = nil; try? FileManager.default.removeItem(at: tempDir) }

            _ = try await CreateGoalV2Tool().executeResult(context: context, arguments: [
                "title": ToolArgument("Same Conv Goal"),
                "tasks": ToolArgument([["title": "T1"]]),
            ])
            let goalId = try #require(await manager.fetchGoals(conversationId: context.conversationID.uuidString).first?.id)

            let progress = try await GetGoalProgressV2Tool().executeResult(context: context, arguments: ["goal_id": ToolArgument(goalId)])
            #expect(progress.isError == false)
            #expect(progress.content.contains("Same Conv Goal"))

            // 完成后仍可用精确 ID 解析（终态 Goal 依然属于本会话）。
            _ = try await UpdateGoalStatusV2Tool().executeResult(context: context, arguments: ["goal_id": ToolArgument(goalId), "status": ToolArgument("completed")])
            let after = try await GetGoalProgressV2Tool().executeResult(context: context, arguments: ["goal_id": ToolArgument(goalId)])
            #expect(after.isError == false)
            #expect(after.content.contains("completed"))
        }
    }
}
