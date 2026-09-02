import Foundation
import KitAgentTool
import ProviderConversation
import Testing
@testable import GoalTaskPlugin

@Suite("GoalTask V2")
struct GoalTaskV2Tests {
    @Test @MainActor func preservesPluginIdentityAndPolicy() {
        let plugin = GoalTaskSuperPlugin()
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
        GoalTaskPlugin._sharedManager = manager
        defer { GoalTaskPlugin._sharedManager = nil }

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
}
