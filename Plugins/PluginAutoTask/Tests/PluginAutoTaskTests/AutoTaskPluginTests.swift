import AgentToolKit
import Foundation
import LumiCoreKit
import SwiftData
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
        #expect(AutoTaskPlugin.policy == .alwaysOn)
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
    let createProperties = try #require(createSchema["properties"] as? [String: Any])
    let createTasks = try #require(createProperties["tasks"] as? [String: Any])
    #expect(try #require(createTasks["minItems"] as? Int) == 1)
    let createTaskItems = try #require(createTasks["items"] as? [String: Any])
    let createTaskProperties = try #require(createTaskItems["properties"] as? [String: Any])
    let createTaskTitle = try #require(createTaskProperties["title"] as? [String: Any])
    #expect(try #require(createTaskTitle["minLength"] as? Int) == 1)

    let appendSchema = AppendTaskTool().inputSchema(for: .english)
    #expect(try #require(appendSchema["required"] as? [String]) == ["tasks"])
    let appendProperties = try #require(appendSchema["properties"] as? [String: Any])
    let appendTasks = try #require(appendProperties["tasks"] as? [String: Any])
    #expect(try #require(appendTasks["minItems"] as? Int) == 1)
    let appendTaskItems = try #require(appendTasks["items"] as? [String: Any])
    let appendTaskProperties = try #require(appendTaskItems["properties"] as? [String: Any])
    let appendTaskTitle = try #require(appendTaskProperties["title"] as? [String: Any])
    #expect(try #require(appendTaskTitle["minLength"] as? Int) == 1)

    let updateSchema = UpdateTaskTool().inputSchema(for: .english)
    #expect(try #require(updateSchema["required"] as? [String]) == ["task_id", "status"])

    #expect(CreateTaskTool().permissionRiskLevel(arguments: [:]) == .low)
    #expect(AppendTaskTool().permissionRiskLevel(arguments: [:]) == .low)
    #expect(UpdateTaskTool().permissionRiskLevel(arguments: [:]) == .low)
    #expect(ListTasksTool().permissionRiskLevel(arguments: [:]) == .low)
    #expect(CheckProgressTool().permissionRiskLevel(arguments: [:]) == .low)
}

@Test func testTaskToolInputNormalizerTrimsTitlesAndDetails() {
    let items = TaskToolInputNormalizer.normalize([
        ["title": "  Write tests  ", "detail": "\nCover whitespace input  "],
        ["title": "\n\t  ", "detail": "hidden"],
        ["title": "Ship fix", "detail": "   "],
    ])

    #expect(items.count == 2)
    #expect(items[0].title == "Write tests")
    #expect(items[0].detail == "Cover whitespace input")
    #expect(items[1].title == "Ship fix")
    #expect(items[1].detail == nil)
}

@Test func testTaskStoreRecoversWhenDatabaseDirectoryIsBlocked() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("auto-task-store-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let blockedDirectory = root.appendingPathComponent("AutoTaskPlugin", isDirectory: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let container = TaskStateManager.makeContainer(databaseRootURL: root)
    let context = ModelContext(container)
    let task = TaskItem(conversationId: "conversation", title: "Recovered task", order: 1)

    context.insert(task)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<TaskItem>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.title == "Recovered task")
}

@Test func testTaskManagerReportsUpdateAndDeletePersistenceResults() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("auto-task-manager-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = TaskStateManager(databaseRootURL: root)
    let created = try await manager.createTask(
        conversationId: "conversation",
        title: "Original",
        detail: "Old detail",
        order: 1
    )

    let updated = await manager.updateTask(id: created.id, title: "Updated", detail: "New detail")
    let fetchedAfterUpdate = try #require(await manager.fetchTask(id: created.id))
    let deleted = await manager.deleteTask(id: created.id)
    let fetchedAfterDelete = await manager.fetchTask(id: created.id)

    #expect(updated)
    #expect(fetchedAfterUpdate.title == "Updated")
    #expect(fetchedAfterUpdate.detail == "New detail")
    #expect(deleted)
    #expect(fetchedAfterDelete == nil)
}
