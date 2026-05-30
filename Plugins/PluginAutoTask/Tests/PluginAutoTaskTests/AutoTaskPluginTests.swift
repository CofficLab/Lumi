import AgentToolKit
import LumiCoreKit
import Testing
@testable import PluginAutoTask

@Suite("PluginAutoTask")
struct AutoTaskPluginTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(AutoTaskPlugin.id == "AutoTask")
        #expect(AutoTaskPlugin.displayName == "Auto Task")
        #expect(AutoTaskPlugin.description.isEmpty == false)
        #expect(AutoTaskPlugin.iconName == "checklist")
        #expect(AutoTaskPlugin.isConfigurable == false)
        #expect(AutoTaskPlugin.category == .agent)
        #expect(AutoTaskPlugin.order == 90)
        #expect(AutoTaskPlugin.enable == true)
    }

    @MainActor
    @Test("plugin registers task tools and middleware")
    func pluginContributions() {
        let tools = AutoTaskPlugin.shared.agentTools(context: ToolContext())

        #expect(tools.map(\.name) == [
            "create_task",
            "append_task",
            "update_task",
            "list_tasks",
            "check_progress",
        ])
        #expect(AutoTaskPlugin.shared.sendMiddlewares().count == 2)
    }
}

@Test func testTaskItemCreation() async throws {
    let task = TaskItem(conversationId: "test-conv", title: "Test Task", detail: "A detail")
    #expect(!task.id.isEmpty)
    #expect(task.conversationId == "test-conv")
    #expect(task.title == "Test Task")
    #expect(task.detail == "A detail")
    #expect(task.status == .pending)
}

@Test func testTaskStatusValues() async throws {
    #expect(TaskItem.TaskStatus(rawValue: "pending") == .pending)
    #expect(TaskItem.TaskStatus(rawValue: "in_progress") == .inProgress)
    #expect(TaskItem.TaskStatus(rawValue: "completed") == .completed)
    #expect(TaskItem.TaskStatus(rawValue: "skipped") == .skipped)
}

@Test func testProgressSummary() async throws {
    let summary = TaskProgressSummary(total: 10, completed: 3, inProgress: 1, pending: 5, skipped: 1)
    #expect(summary.completionPercent == 40)
    #expect(!summary.isAllDone)
    #expect(!summary.isEmpty)

    let allDone = TaskProgressSummary(total: 5, completed: 4, inProgress: 0, pending: 0, skipped: 1)
    #expect(allDone.isAllDone)

    let empty = TaskProgressSummary(total: 0, completed: 0, inProgress: 0, pending: 0, skipped: 0)
    #expect(empty.isEmpty)
}

@Test func testToolSchemasAndRiskLevels() throws {
    let createSchema = CreateTaskTool().inputSchema(for: .english)
    #expect(try #require(createSchema["required"] as? [String]) == ["tasks"])

    let appendSchema = AppendTaskTool().inputSchema(for: .english)
    #expect(try #require(appendSchema["required"] as? [String]) == ["tasks"])

    let updateSchema = UpdateTaskTool().inputSchema(for: .english)
    #expect(try #require(updateSchema["required"] as? [String]) == ["task_id", "status"])

    #expect(CreateTaskTool().permissionRiskLevel(arguments: [:]) == .low)
    #expect(AppendTaskTool().permissionRiskLevel(arguments: [:]) == .low)
    #expect(UpdateTaskTool().permissionRiskLevel(arguments: [:]) == .low)
    #expect(ListTasksTool().permissionRiskLevel(arguments: [:]) == .low)
    #expect(CheckProgressTool().permissionRiskLevel(arguments: [:]) == .low)
}
