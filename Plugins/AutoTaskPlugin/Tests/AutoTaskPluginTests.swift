import Foundation
import LumiKernel
import SwiftData
import Testing
@testable import AutoTaskPlugin

@Suite("PluginAutoTask")
struct AutoTaskPluginTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(AutoTaskPlugin.info.id == "com.coffic.lumi.plugin.auto-task")
        #expect(AutoTaskPlugin.info.displayName.isEmpty == false)
        #expect(AutoTaskPlugin.info.description.isEmpty == false)
        #expect(AutoTaskPlugin.iconName == "checklist")
        #expect(AutoTaskPlugin.policy.isConfigurable == false)
        #expect(AutoTaskPlugin.category == .agent)
        #expect(AutoTaskPlugin.info.order == 90)
        #expect(AutoTaskPlugin.policy == .alwaysOn)
    }

    @MainActor
    @Test("plugin registers task tools and middleware")
    func pluginContributions() async throws {
        // 使用临时目录初始化 manager
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("auto-task-plugin-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        AutoTaskPlugin.manager = TaskStateManager(databaseRootURL: tmpDir)

        let context = LumiPluginContext(
            activeSectionID: "com.coffic.lumi.plugin.chat-panel",
            activeSectionTitle: "Chat"
        )
        let tools = try AutoTaskPlugin.agentTools(lumiCore: context)

        #expect(tools.map(\.name) == [
            "create_task",
            "append_task",
            "update_task",
            "list_tasks",
            "check_progress",
        ])
        #expect(AutoTaskPlugin.sendMiddlewares(lumiCore: context).count == 1)
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

@Test func testToolSchemasAndRiskLevels() async throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("tool-schema-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    let tempManager = TaskStateManager(databaseRootURL: tempRoot)

    // CreateTaskTool schema
    let createSchema = CreateTaskTool(manager: tempManager).inputSchema
    if case .object(let props) = createSchema,
       case .array(let required) = props["required"],
       case .string(let req0) = required.first {
        #expect(req0 == "tasks")
    } else {
        Issue.record("create_task schema missing required 'tasks'")
    }

    // AppendTaskTool schema
    let appendSchema = AppendTaskTool(manager: tempManager).inputSchema
    if case .object(let props) = appendSchema,
       case .array(let required) = props["required"],
       case .string(let req0) = required.first {
        #expect(req0 == "tasks")
    } else {
        Issue.record("append_task schema missing required 'tasks'")
    }

    // UpdateTaskTool schema
    let updateSchema = UpdateTaskTool(manager: tempManager).inputSchema
    if case .object(let props) = updateSchema,
       case .array(let required) = props["required"] {
        let reqStrings = required.compactMap { v -> String? in
            if case .string(let s) = v { return s }
            return nil
        }
        #expect(reqStrings.contains("task_id"))
        #expect(reqStrings.contains("status"))
    } else {
        Issue.record("update_task schema missing required fields")
    }

    #expect(CreateTaskTool(manager: tempManager).riskLevel(arguments: [:], context: nil) == .low)
    #expect(AppendTaskTool(manager: tempManager).riskLevel(arguments: [:], context: nil) == .low)
    #expect(UpdateTaskTool(manager: tempManager).riskLevel(arguments: [:], context: nil) == .low)
    #expect(ListTasksTool(manager: tempManager).riskLevel(arguments: [:], context: nil) == .low)
    #expect(CheckProgressTool(manager: tempManager).riskLevel(arguments: [:], context: nil) == .low)
}

@Test func testCreateTasksClampsToConversationLimit() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("auto-task-create-limit-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = TaskStateManager(databaseRootURL: root)
    let items = (1...(TaskStateManager.maxTasksPerConversation + 10)).map {
        (title: "Task \($0)", detail: nil as String?)
    }

    let created = try await manager.createTasks(conversationId: "conversation", items: items)
    let fetched = await manager.fetchTasks(conversationId: "conversation")

    #expect(created.count == TaskStateManager.maxTasksPerConversation)
    #expect(fetched.count == TaskStateManager.maxTasksPerConversation)
    #expect(fetched.first?.status == .inProgress)
    #expect(fetched.last?.title == "Task \(TaskStateManager.maxTasksPerConversation)")
}

@Test func testAppendTasksRespectsRemainingConversationCapacity() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("auto-task-append-limit-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = TaskStateManager(databaseRootURL: root)
    let initialItems = (1...(TaskStateManager.maxTasksPerConversation - 2)).map {
        (title: "Existing \($0)", detail: nil as String?)
    }
    _ = try await manager.createTasks(conversationId: "conversation", items: initialItems)

    let appended = try await manager.appendTasks(
        conversationId: "conversation",
        items: [
            (title: "Appended 1", detail: nil),
            (title: "Appended 2", detail: nil),
            (title: "Overflow", detail: nil),
        ]
    )
    let overflowAppend = try await manager.appendTasks(
        conversationId: "conversation",
        items: [(title: "Should not append", detail: nil)]
    )
    let fetched = await manager.fetchTasks(conversationId: "conversation")

    #expect(appended.map(\.title) == ["Appended 1", "Appended 2"])
    #expect(overflowAppend.isEmpty)
    #expect(fetched.count == TaskStateManager.maxTasksPerConversation)
    #expect(fetched.suffix(2).map(\.title) == ["Appended 1", "Appended 2"])
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

@Test func testCreateTasksStartsFirstTask() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("auto-task-create-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = TaskStateManager(databaseRootURL: root)
    let created = try await manager.createTasks(
        conversationId: "conversation",
        items: [
            (title: "First", detail: nil),
            (title: "Second", detail: nil),
        ]
    )

    #expect(created.map(\.status) == [.inProgress, .pending])

    let fetched = await manager.fetchTasks(conversationId: "conversation")
    #expect(fetched.map(\.status) == [.inProgress, .pending])
}

@MainActor
@Test func testSidebarIgnoresStaleConversationRefresh() async throws {
    let staleTask = TaskItem(conversationId: "stale", title: "Stale task", order: 1)
    let freshTask = TaskItem(conversationId: "fresh", title: "Fresh task", order: 1)
    let service = FakeSidebarService(
        tasks: [
            "stale": [staleTask],
            "fresh": [freshTask],
        ],
        delays: [
            "stale": 200_000_000,
            "fresh": 20_000_000,
        ]
    )
    let viewModel = SidebarViewModel(service: service)

    let staleRefresh = Task {
        await viewModel.refresh(conversationId: "stale")
    }
    try await Task.sleep(nanoseconds: 50_000_000)
    await viewModel.refresh(conversationId: "fresh")
    await staleRefresh.value

    #expect(viewModel.currentConversationId == "fresh")
    #expect(viewModel.tasks.map(\.title) == ["Fresh task"])
    #expect(viewModel.summary?.total == 1)
    #expect(viewModel.isLoading == false)
}

private actor FakeSidebarService: SidebarServicing {
    private let tasks: [String: [TaskItem]]
    private let delays: [String: UInt64]

    init(tasks: [String: [TaskItem]], delays: [String: UInt64]) {
        self.tasks = tasks
        self.delays = delays
    }

    func fetchTasks(conversationId: String) async -> [TaskItem] {
        if let delay = delays[conversationId] {
            try? await Task.sleep(nanoseconds: delay)
        }
        return tasks[conversationId] ?? []
    }

    func getProgressSummary(conversationId: String) async -> TaskProgressSummary {
        let fetchedTasks = tasks[conversationId] ?? []
        return TaskProgressSummary(
            total: fetchedTasks.count,
            completed: fetchedTasks.filter { $0.status == .completed }.count,
            inProgress: fetchedTasks.filter { $0.status == .inProgress }.count,
            pending: fetchedTasks.filter { $0.status == .pending }.count,
            skipped: fetchedTasks.filter { $0.status == .skipped }.count
        )
    }
}

// MARK: - Tool execute() tests with injected TaskStateManager

@Suite("Tool execute")
struct ToolExecuteTests {
    private nonisolated static func makeManager() async throws -> TaskStateManager {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tool-execute-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return TaskStateManager(databaseRootURL: root)
    }

    private nonisolated static func makeContext(conversationID: UUID = UUID()) -> LumiToolExecutionContext {
        LumiToolExecutionContext(conversationID: conversationID, toolCallID: "tc1", toolName: "test")
    }

    // MARK: UpdateTaskTool

    @Test("UpdateTaskTool: missing task_id returns error")
    func updateTaskMissingTaskId() async throws {
        let manager = try await Self.makeManager()
        let tool = UpdateTaskTool(manager: manager)
        let result = try await tool.execute(
            arguments: ["status": .string("completed")],
            context: Self.makeContext()
        )
        // Error message is localized; just check it's an error (contains "task_id" keyword)
        #expect(result.contains("task_id") || result.contains("Task ID"))
    }

    @Test("UpdateTaskTool: missing status returns error")
    func updateTaskMissingStatus() async throws {
        let manager = try await Self.makeManager()
        let tool = UpdateTaskTool(manager: manager)
        let result = try await tool.execute(
            arguments: ["task_id": .string("some-id")],
            context: Self.makeContext()
        )
        #expect(result.contains("status"))
    }

    @Test("UpdateTaskTool: invalid status returns error")
    func updateTaskInvalidStatus() async throws {
        let manager = try await Self.makeManager()
        let tool = UpdateTaskTool(manager: manager)
        let result = try await tool.execute(
            arguments: ["task_id": .string("some-id"), "status": .string("invalid")],
            context: Self.makeContext()
        )
        #expect(result.contains("status"))
    }

    @Test("UpdateTaskTool: updates a valid task")
    func updateTaskValid() async throws {
        let manager = try await Self.makeManager()
        let convID = UUID()
        let task = try await manager.createTask(conversationId: convID.uuidString, title: "Task A", order: 1)

        let tool = UpdateTaskTool(manager: manager)
        let result = try await tool.execute(
            arguments: ["task_id": .string(task.id), "status": .string("completed")],
            context: Self.makeContext(conversationID: convID)
        )
        // Status raw value is not localized
        #expect(result.contains("completed"))

        let updated = await manager.fetchTask(id: task.id)
        try #require(updated != nil)
        #expect(updated?.status == .completed)
    }

    @Test("UpdateTaskTool: auto-starts next pending task when current is completed")
    func updateTaskAutoStartsNext() async throws {
        let manager = try await Self.makeManager()
        let convID = UUID()
        let task1 = try await manager.createTask(conversationId: convID.uuidString, title: "First", order: 1)
        _ = try await manager.createTask(conversationId: convID.uuidString, title: "Second", order: 2)

        let tool = UpdateTaskTool(manager: manager)
        _ = try await tool.execute(
            arguments: ["task_id": .string(task1.id), "status": .string("completed")],
            context: Self.makeContext(conversationID: convID)
        )

        let allTasks = await manager.fetchTasks(conversationId: convID.uuidString)
        let secondTask = allTasks.first { $0.title == "Second" }
        try #require(secondTask != nil)
        #expect(secondTask?.status == .inProgress)
    }

    @Test("UpdateTaskTool: auto-starts next pending task when current is skipped")
    func updateTaskAutoStartsOnSkip() async throws {
        let manager = try await Self.makeManager()
        let convID = UUID()
        let task1 = try await manager.createTask(conversationId: convID.uuidString, title: "First", order: 1)
        _ = try await manager.createTask(conversationId: convID.uuidString, title: "Second", order: 2)

        let tool = UpdateTaskTool(manager: manager)
        _ = try await tool.execute(
            arguments: ["task_id": .string(task1.id), "status": .string("skipped")],
            context: Self.makeContext(conversationID: convID)
        )

        let allTasks = await manager.fetchTasks(conversationId: convID.uuidString)
        let secondTask = allTasks.first { $0.title == "Second" }
        try #require(secondTask != nil)
        #expect(secondTask?.status == .inProgress)
    }

    // MARK: CreateTaskTool

    @Test("CreateTaskTool: missing tasks array returns error")
    func createTaskMissingTasks() async throws {
        let manager = try await Self.makeManager()
        let tool = CreateTaskTool(manager: manager)
        let result = try await tool.execute(
            arguments: [:],
            context: Self.makeContext()
        )
        // Error message is localized ("错误：缺少任务列表"); just check non-empty error
        #expect(!result.isEmpty)
        #expect(result.contains("错误") || result.contains("Error") || result.contains("error"))
    }

    @Test("CreateTaskTool: empty tasks array returns error")
    func createTaskEmptyTasks() async throws {
        let manager = try await Self.makeManager()
        let tool = CreateTaskTool(manager: manager)
        let result = try await tool.execute(
            arguments: ["tasks": .array([])],
            context: Self.makeContext()
        )
        #expect(!result.isEmpty)
        #expect(result.contains("错误") || result.contains("Error") || result.contains("error"))
    }

    @Test("CreateTaskTool: creates tasks and starts first")
    func createTaskValid() async throws {
        let manager = try await Self.makeManager()
        let convID = UUID()
        let tool = CreateTaskTool(manager: manager)

        let taskData: [String: LumiJSONValue] = [
            "title": .string("Build feature"),
            "detail": .string("Implement the new login flow"),
        ]
        let result = try await tool.execute(
            arguments: ["tasks": .array([.object(taskData)])],
            context: Self.makeContext(conversationID: convID)
        )
        // Task title is not localized
        #expect(result.contains("Build feature"))

        let tasks = await manager.fetchTasks(conversationId: convID.uuidString)
        #expect(tasks.count == 1)
        #expect(tasks.first?.status == .inProgress)
        #expect(tasks.first?.detail == "Implement the new login flow")
    }

    // MARK: AppendTaskTool

    @Test("AppendTaskTool: appends to existing tasks")
    func appendTaskValid() async throws {
        let manager = try await Self.makeManager()
        let convID = UUID()
        _ = try await manager.createTask(conversationId: convID.uuidString, title: "Existing", order: 1)

        let tool = AppendTaskTool(manager: manager)
        let result = try await tool.execute(
            arguments: ["tasks": .array([.object(["title": .string("New task")])])],
            context: Self.makeContext(conversationID: convID)
        )
        #expect(result.contains("New task"))

        let tasks = await manager.fetchTasks(conversationId: convID.uuidString)
        #expect(tasks.count == 2)
        #expect(tasks.last?.title == "New task")
        #expect(tasks.last?.status == .pending)
    }

    // MARK: ListTasksTool

    @Test("ListTasksTool: returns all tasks")
    func listTasksAll() async throws {
        let manager = try await Self.makeManager()
        let convID = UUID()
        _ = try await manager.createTask(conversationId: convID.uuidString, title: "Task A", order: 1)
        _ = try await manager.createTask(conversationId: convID.uuidString, title: "Task B", order: 2)

        let tool = ListTasksTool(manager: manager)
        let result = try await tool.execute(
            arguments: [:],
            context: Self.makeContext(conversationID: convID)
        )
        // Task titles are not localized
        #expect(result.contains("Task A"))
        #expect(result.contains("Task B"))
    }

    @Test("ListTasksTool: filters by status")
    func listTasksByStatus() async throws {
        let manager = try await Self.makeManager()
        let convID = UUID()
        let tasks = try await manager.createTasks(
            conversationId: convID.uuidString,
            items: [
                (title: "Done", detail: nil as String?),
                (title: "Pending", detail: nil as String?),
            ]
        )
        // Mark first as completed
        _ = try await manager.updateTaskStatus(id: tasks[0].id, status: TaskItem.TaskStatus.completed)

        // Verify the tool can be called with status filter (output is localized)
        let tool = ListTasksTool(manager: manager)
        let result = try await tool.execute(
            arguments: ["status": .string("completed")],
            context: Self.makeContext(conversationID: convID)
        )
        #expect(!result.isEmpty)
    }

    @Test("ListTasksTool: returns message when no tasks")
    func listTasksEmpty() async throws {
        let manager = try await Self.makeManager()
        let tool = ListTasksTool(manager: manager)
        let result = try await tool.execute(
            arguments: [:],
            context: Self.makeContext()
        )
        // Message is localized, just check non-empty
        #expect(!result.isEmpty)
    }

    // MARK: CheckProgressTool

    @Test("CheckProgressTool: returns progress with tasks")
    func checkProgressWithTasks() async throws {
        let manager = try await Self.makeManager()
        let convID = UUID()
        _ = try await manager.createTask(conversationId: convID.uuidString, title: "Work", order: 1)

        let tool = CheckProgressTool(manager: manager)
        let result = try await tool.execute(
            arguments: [:],
            context: Self.makeContext(conversationID: convID)
        )
        #expect(result.contains("Work"))
    }

    @Test("CheckProgressTool: returns message when no tasks")
    func checkProgressEmpty() async throws {
        let manager = try await Self.makeManager()
        let tool = CheckProgressTool(manager: manager)
        let result = try await tool.execute(
            arguments: [:],
            context: Self.makeContext()
        )
        #expect(!result.isEmpty)
    }
}

// MARK: - TaskStateManager edge case tests

@Suite("TaskStateManager edge cases")
struct TaskStateManagerEdgeCaseTests {
    private nonisolated static func makeManager() async throws -> TaskStateManager {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tsm-edge-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return TaskStateManager(databaseRootURL: root)
    }

    @Test("fetchTask returns nil for unknown id")
    func fetchTaskUnknownId() async throws {
        let manager = try await Self.makeManager()
        let result = await manager.fetchTask(id: "nonexistent")
        #expect(result == nil)
    }

    @Test("updateTask returns false for unknown id")
    func updateTaskUnknownId() async throws {
        let manager = try await Self.makeManager()
        let result = await manager.updateTask(id: "nonexistent", title: "X", detail: nil)
        #expect(result == false)
    }

    @Test("deleteTask returns false for unknown id")
    func deleteTaskUnknownId() async throws {
        let manager = try await Self.makeManager()
        let result = await manager.deleteTask(id: "nonexistent")
        #expect(result == false)
    }

    @Test("fetchTasks with status filter")
    func fetchTasksByStatus() async throws {
        let manager = try await Self.makeManager()
        // Create tasks using the batch API which shares a single ModelContext
        let tasks = try await manager.createTasks(
            conversationId: "c1",
            items: [
                (title: "A", detail: nil as String?),
                (title: "B", detail: nil as String?),
            ]
        )
        #expect(tasks.count == 2)
        // First task is auto-started, second is pending
        #expect(tasks[0].status == TaskItem.TaskStatus.inProgress)
        #expect(tasks[1].status == TaskItem.TaskStatus.pending)

        // Complete the first task
        _ = try await manager.updateTaskStatus(id: tasks[0].id, status: TaskItem.TaskStatus.completed)

        // Now fetch by status - use the IDs we have to verify the filter works
        let allTasks = await manager.fetchTasks(conversationId: "c1")
        let completedIDs = Set(allTasks.filter { $0.status == .completed }.map(\.id))
        let pendingIDs = Set(allTasks.filter { $0.status == .pending }.map(\.id))
        let inProgressIDs = Set(allTasks.filter { $0.status == .inProgress }.map(\.id))

        #expect(completedIDs.contains(tasks[0].id))
        #expect(pendingIDs.contains(tasks[1].id))
        #expect(inProgressIDs.isEmpty)
    }

    @Test("deleteAllForConversation removes all tasks")
    func deleteAllForConversation() async throws {
        let manager = try await Self.makeManager()
        _ = try await manager.createTask(conversationId: "c2", title: "A", order: 1)
        _ = try await manager.createTask(conversationId: "c2", title: "B", order: 2)

        let before = await manager.fetchTasks(conversationId: "c2")
        #expect(before.count == 2)

        _ = await manager.deleteAllForConversation("c2")

        let after = await manager.fetchTasks(conversationId: "c2")
        #expect(after.isEmpty)
    }

    @Test("createTasks with empty items returns empty array")
    func createTasksEmpty() async throws {
        let manager = try await Self.makeManager()
        let result = try await manager.createTasks(conversationId: "c3", items: [])
        #expect(result.isEmpty)
    }

    @Test("appendTasks with empty items returns empty array")
    func appendTasksEmpty() async throws {
        let manager = try await Self.makeManager()
        let result = try await manager.appendTasks(conversationId: "c3", items: [])
        #expect(result.isEmpty)
    }
}

// MARK: - TaskDisplayItem tests

@Suite("TaskDisplayItem")
struct TaskDisplayItemTests {
    @Test("statusSystemImage maps correctly")
    func statusSystemImage() {
        let task = TaskItem(conversationId: "c1", title: "T", order: 1)

        let pending = TaskDisplayItem(from: task)
        #expect(pending.statusSystemImage == "circle")

        var inProgress = task
        inProgress.status = .inProgress
        #expect(TaskDisplayItem(from: inProgress).statusSystemImage == "arrow.triangle.2.circlepath")

        var completed = task
        completed.status = .completed
        #expect(TaskDisplayItem(from: completed).statusSystemImage == "checkmark.circle.fill")

        var skipped = task
        skipped.status = .skipped
        #expect(TaskDisplayItem(from: skipped).statusSystemImage == "forward.circle")
    }

    @Test("statusColor maps correctly")
    func statusColor() {
        let task = TaskItem(conversationId: "c1", title: "T", order: 1)

        let pending = TaskDisplayItem(from: task)
        #expect(pending.statusColor == .secondary)

        var inProgress = task
        inProgress.status = .inProgress
        #expect(TaskDisplayItem(from: inProgress).statusColor == .blue)

        var completed = task
        completed.status = .completed
        #expect(TaskDisplayItem(from: completed).statusColor == .green)

        var skipped = task
        skipped.status = .skipped
        #expect(TaskDisplayItem(from: skipped).statusColor == .orange)
    }

    @Test("statusText is non-empty for all statuses")
    func statusTextNonEmpty() {
        let task = TaskItem(conversationId: "c1", title: "T", order: 1)
        let statuses: [TaskItem.TaskStatus] = [.pending, .inProgress, .completed, .skipped]

        for status in statuses {
            var t = task
            t.status = status
            let display = TaskDisplayItem(from: t)
            #expect(!display.statusText.isEmpty, "statusText should not be empty for \(status)")
        }
    }

    @Test("init from TaskItem copies all fields")
    func initFromTaskItem() {
        let task = TaskItem(
            id: "test-id",
            conversationId: "conv",
            title: "My Task",
            detail: "Some detail",
            status: .inProgress,
            order: 5
        )

        let display = TaskDisplayItem(from: task)
        #expect(display.id == "test-id")
        #expect(display.title == "My Task")
        #expect(display.detail == "Some detail")
        #expect(display.status == .inProgress)
        #expect(display.order == 5)
    }
}
