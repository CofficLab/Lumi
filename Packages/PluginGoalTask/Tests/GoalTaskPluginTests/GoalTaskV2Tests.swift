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
}
