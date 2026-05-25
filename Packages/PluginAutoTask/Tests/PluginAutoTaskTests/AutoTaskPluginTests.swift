import Testing
@testable import PluginAutoTask

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
