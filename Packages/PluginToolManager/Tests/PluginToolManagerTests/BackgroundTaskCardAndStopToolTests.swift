import Foundation
import KitAgentTool
import KitShell
import ProviderMessage
import Testing
@testable import PluginToolManager

/// `stop_background_task` 工具与后台任务卡片渲染器的行为契约。
@Suite("BackgroundTaskCardAndStopTool")
struct BackgroundTaskCardAndStopToolTests {

    // MARK: - stop_background_task 工具

    @Test("工具名与 schema 声明 task_id")
    func toolDeclaresTaskIDArgument() {
        let tool = StopBackgroundTaskTool()
        #expect(tool.name == "stop_background_task")
        let schema = tool.inputSchema(for: .english)
        let properties = schema["properties"] as? [String: Any]
        #expect(properties?["task_id"] != nil)
        #expect((schema["required"] as? [String]) == ["task_id"])
    }

    @Test("缺少 task_id 时抛错而不是返回字符串")
    func missingTaskIDThrows() async {
        let tool = StopBackgroundTaskTool()
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [:])
        }
    }

    @Test("没有登记表时抛错")
    func missingRegistryThrows() async {
        let tool = StopBackgroundTaskTool(registryProvider: { nil })
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: ["task_id": ToolArgument("nope")])
        }
    }

    @Test("未知任务 ID 时抛错")
    func unknownTaskIDThrows() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let tool = StopBackgroundTaskTool(registryProvider: { registry })

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: ["task_id": ToolArgument("missing")])
        }
    }

    @Test("停止运行中的任务会终止进程")
    func stopsRunningTask() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let tool = StopBackgroundTaskTool(registryProvider: { registry })

        let taskID = await registry.allocateTaskID()
        let handle = try await startBackgroundProcess(command: "sleep 30")
        let pid = handle.processIdentifier
        _ = await registry.adopt(
            taskID: taskID,
            conversationID: UUID(),
            command: "sleep 30",
            handle: handle,
            sink: BackgroundTaskOutputSink()
        )

        let result = try await tool.execute(arguments: ["task_id": ToolArgument(taskID)])
        #expect(result.contains("stopped"))

        try await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(!isProcessRunning(pid))

        let record = await registry.task(for: taskID)
        #expect(record?.status == .stopped)
    }

    @Test("停止已结束的任务返回真实状态而不是报错")
    func stoppingFinishedTaskReportsStatus() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let tool = StopBackgroundTaskTool(registryProvider: { registry })

        let taskID = await registry.allocateTaskID()
        // 预算 0.4s，命令跑 1s：先交接后台，再自然结束。
        let handle = try await startBackgroundProcess(command: "sleep 1")
        _ = await registry.adopt(
            taskID: taskID,
            conversationID: UUID(),
            command: "sleep 1",
            handle: handle,
            sink: BackgroundTaskOutputSink()
        )
        try await Task.sleep(nanoseconds: 2_000_000_000)

        let result = try await tool.execute(arguments: ["task_id": ToolArgument(taskID)])
        #expect(result.contains("already"))
    }

    // MARK: - 卡片渲染器

    @Test("通知消息被卡片渲染器接管")
    func notificationMessageIsRenderedByCard() {
        let message = BackgroundTaskNotification.message(
            conversationID: UUID(),
            taskID: "task-1",
            status: .completed,
            exitCode: 0,
            outputPath: "/tmp/task-1.log",
            tailExcerpt: ""
        )
        #expect(BackgroundTaskCardRenderer.isBackgroundNotification(message))
    }

    @Test("普通消息不被卡片渲染器接管")
    func ordinaryMessageIsNotRenderedByCard() {
        let message = Message(conversationID: UUID(), role: .user, content: "hello")
        #expect(!BackgroundTaskCardRenderer.isBackgroundNotification(message))
    }

    @Test("载荷解析出任务 ID、状态、退出码与输出路径")
    func payloadDecodesFromMetadata() throws {
        let message = BackgroundTaskNotification.message(
            conversationID: UUID(),
            taskID: "task-42",
            status: .failed,
            exitCode: 7,
            outputPath: "/tmp/task-42.log",
            tailExcerpt: ""
        )
        let payload = try #require(
            BackgroundTaskCardRenderer.decodePayload(from: message.metadata)
        )
        #expect(payload.taskID == "task-42")
        #expect(payload.status == .failed)
        #expect(payload.exitCode == 7)
        #expect(payload.outputPath == "/tmp/task-42.log")
    }

    @Test("载荷缺失时返回 nil 以便回退到纯文本")
    func missingPayloadDecodesToNil() {
        #expect(BackgroundTaskCardRenderer.decodePayload(from: [:]) == nil)
        #expect(
            BackgroundTaskCardRenderer.decodePayload(from: [
                BackgroundTaskNotification.taskIDKey: "task-1",
            ]) == nil
        )
    }

    @Test("未知状态值不会导致崩溃")
    func unknownStatusDecodesToNil() {
        #expect(
            BackgroundTaskCardRenderer.decodePayload(from: [
                BackgroundTaskNotification.taskIDKey: "task-1",
                BackgroundTaskNotification.statusKey: "not-a-status",
            ]) == nil
        )
    }
}

// MARK: - Helpers

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("BackgroundTaskCardTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func startBackgroundProcess(command: String) async throws -> BackgroundShellHandle {
    let outcome = try await ShellExecutor.executeStreamingWithBackgroundHandoff(
        command,
        options: .init(timeout: 0.4, throwsOnError: false)
    )
    guard case .backgrounded(let handle) = outcome else {
        Issue.record("预算耗尽后应返回 .backgrounded")
        throw BackgroundTaskCardTestError.expectedBackgrounded
    }
    return handle
}

private func isProcessRunning(_ pid: Int32) -> Bool {
    guard pid > 0 else { return false }
    return kill(pid, 0) == 0
}

private enum BackgroundTaskCardTestError: Error {
    case expectedBackgrounded
}
