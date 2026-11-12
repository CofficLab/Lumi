import Foundation
import KitShell
import Testing
@testable import PluginToolManager

/// 后台任务登记表的行为契约。
///
/// 核心约定：
/// - 每个任务**恰好一次**完成事件（进程退出与显式停止并发也不重复）
/// - 取消回合**不得**杀后台任务；删除会话**必须**杀
/// - 重启后运行中的记录标记为「已中断」，不重挂孤儿进程
@Suite("BackgroundTaskRegistry")
struct BackgroundTaskRegistryTests {

    // MARK: - 登记与退出检测

    @Test("进程退出后任务被标记为完成并发出恰好一次完成事件")
    func taskFinishesExactlyOnceOnProcessExit() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let events = EventRecorder()

        let taskID = await registry.allocateTaskID()
        let sink = BackgroundTaskOutputSink()
        let handle = try await startBackgroundProcess(command: "sleep 1")
        _ = await registry.adopt(
            taskID: taskID,
            conversationID: UUID(),
            command: "sleep 1",
            handle: handle,
            sink: sink
        )
        _ = await registry.addObserver { event in
            events.record(event)
        }

        try await Task.sleep(nanoseconds: 2_500_000_000)

        let finished = events.finishedRecords()
        #expect(finished.count == 1)
        #expect(finished.first?.status == .completed)

        let record = await registry.task(for: taskID)
        #expect(record?.status == .completed)
        #expect(record?.exitCode == 0)
    }

    @Test("非零退出码被记录为失败")
    func nonZeroExitCodeMarksTaskFailed() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let events = EventRecorder()

        let taskID = await registry.allocateTaskID()
        let handle = try await startBackgroundProcess(command: "sleep 1; exit 3")
        _ = await registry.adopt(
            taskID: taskID,
            conversationID: UUID(),
            command: "sleep 1; exit 3",
            handle: handle,
            sink: BackgroundTaskOutputSink()
        )
        _ = await registry.addObserver { event in
            events.record(event)
        }

        try await Task.sleep(nanoseconds: 3_000_000_000)

        let record = await registry.task(for: taskID)
        #expect(record?.status == .failed)
        #expect(record?.exitCode == 3)
        #expect(events.finishedRecords().count == 1)
    }

    // MARK: - 输出文件

    @Test("输出被写入任务文件并可读取尾部")
    func outputIsWrittenToTaskFile() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let taskID = await registry.allocateTaskID()
        let sink = BackgroundTaskOutputSink()

        // 交接前产生的输出先暂存，交接时按顺序冲刷。
        sink.append("first line\n")
        sink.append("second line\n")

        let handle = try await startBackgroundProcess(command: "sleep 1")
        _ = await registry.adopt(
            taskID: taskID,
            conversationID: UUID(),
            command: "sleep 1",
            handle: handle,
            sink: sink
        )

        let outputPath = await registry.outputPath(for: taskID)
        let fileURL = URL(fileURLWithPath: outputPath)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let contents = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        #expect(contents.contains("first line"))
        #expect(contents.contains("second line"))
    }

    @Test("输出超过磁盘上限时保留尾部并标记截断")
    func oversizedOutputKeepsTailAndMarksTruncation() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("capped.log")
        let cap = 200
        let writer = try BackgroundTaskOutputWriter(fileURL: fileURL, maxBytes: cap)

        // 先写满到上限，再追加一段超出上限的内容触发裁剪。
        writer.append(String(repeating: "a", count: cap))
        writer.append("TAILMARKER\n")

        #expect(writer.isTruncated)

        // 尾部与截断提示都必须留在文件里：模型靠它们判断「输出被裁剪了」。
        let contents = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        #expect(contents.contains("TAILMARKER"))
        #expect(contents.contains("[output truncated"))
        #expect(contents.count <= cap + BackgroundTaskOutputWriter.truncationNotice.count)
    }

    // MARK: - 显式停止

    @Test("显式停止会终止进程并只发出一次完成事件")
    func explicitStopTerminatesProcessAndEmitsOnce() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let events = EventRecorder()

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
        _ = await registry.addObserver { event in
            events.record(event)
        }

        let stopped = await registry.stop(taskID: taskID)
        #expect(stopped)

        // 进程被杀掉之后，等待它自然退出的那条路径不会再发第二次通知。
        try await Task.sleep(nanoseconds: 1_500_000_000)

        #expect(events.finishedRecords().count == 1)
        #expect(events.finishedRecords().first?.status == .stopped)
        #expect(!isProcessRunning(pid))

        let record = await registry.task(for: taskID)
        #expect(record?.status == .stopped)
    }

    @Test("重复停止同一个任务不会重复发出完成事件")
    func repeatedStopIsIdempotent() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let events = EventRecorder()

        let taskID = await registry.allocateTaskID()
        let handle = try await startBackgroundProcess(command: "sleep 30")
        _ = await registry.adopt(
            taskID: taskID,
            conversationID: UUID(),
            command: "sleep 30",
            handle: handle,
            sink: BackgroundTaskOutputSink()
        )
        _ = await registry.addObserver { event in
            events.record(event)
        }

        #expect(await registry.stop(taskID: taskID) == true)
        #expect(await registry.stop(taskID: taskID) == false)

        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(events.finishedRecords().count == 1)
    }

    // MARK: - 会话级清理

    @Test("删除会话会停止该会话的全部后台任务")
    func deletingConversationStopsItsBackgroundTasks() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let conversationID = UUID()
        let otherConversationID = UUID()

        let first = try await startBackgroundProcess(command: "sleep 30")
        let second = try await startBackgroundProcess(command: "sleep 30")
        _ = await registry.adopt(
            taskID: await registry.allocateTaskID(),
            conversationID: conversationID,
            command: "sleep 30",
            handle: first,
            sink: BackgroundTaskOutputSink()
        )
        _ = await registry.adopt(
            taskID: await registry.allocateTaskID(),
            conversationID: otherConversationID,
            command: "sleep 30",
            handle: second,
            sink: BackgroundTaskOutputSink()
        )

        let stopped = await registry.stopAll(forConversationID: conversationID)
        #expect(stopped == 1)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(!isProcessRunning(first.processIdentifier))
        #expect(isProcessRunning(second.processIdentifier))

        // 其它会话的任务不受影响。
        _ = await registry.stopAll()
    }

    // MARK: - 重启恢复

    @Test("重启后运行中的记录被标记为已中断")
    func runningRecordsBecomeInterruptedAfterRestart() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        let first = BackgroundTaskRegistry(rootDirectory: directory)
        let taskID = await first.allocateTaskID()
        let handle = try await startBackgroundProcess(command: "sleep 30")
        _ = await first.adopt(
            taskID: taskID,
            conversationID: conversationID,
            command: "sleep 30",
            handle: handle,
            sink: BackgroundTaskOutputSink()
        )

        // 模拟「应用重启」：新进程打开同一个数据目录。
        // v1 不重挂孤儿进程，运行中的记录必须被标记为「已中断」。
        let second = BackgroundTaskRegistry(rootDirectory: directory)
        let record = await second.task(for: taskID)
        #expect(record != nil)
        #expect(record?.status == .interrupted)
        #expect(record?.conversationID == conversationID)

        // 清理孤儿进程。
        handle.terminate()
    }

    // MARK: - 输出路径

    @Test("输出路径位于 background-tasks 目录且以任务 ID 命名")
    func outputPathLivesInCanonicalDirectory() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let taskID = await registry.allocateTaskID()
        let path = await registry.outputPath(for: taskID)

        #expect(path.hasSuffix("background-tasks/\(taskID).log"))
        #expect(path.contains(directory.path))
    }
}

// MARK: - Helpers

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("BackgroundTaskRegistryTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// 启动一个后台进程并把它交给后台（模拟预算耗尽后的交接）。
private func startBackgroundProcess(command: String) async throws -> BackgroundShellHandle {
    let outcome = try await ShellExecutor.executeStreamingWithBackgroundHandoff(
        command,
        options: .init(timeout: 0.4, throwsOnError: false)
    )
    guard case .backgrounded(let handle) = outcome else {
        Issue.record("预算耗尽后应返回 .backgrounded")
        throw BackgroundTaskTestError.expectedBackgrounded
    }
    return handle
}

private func isProcessRunning(_ pid: Int32) -> Bool {
    guard pid > 0 else { return false }
    return kill(pid, 0) == 0
}

private enum BackgroundTaskTestError: Error {
    case expectedBackgrounded
}

/// 线程安全的事件记录器。
private final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [BackgroundTaskEvent] = []

    func record(_ event: BackgroundTaskEvent) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }

    func finishedRecords() -> [BackgroundTaskRecord] {
        lock.lock()
        defer { lock.unlock() }
        return storage.compactMap { event in
            if case .finished(let record) = event { return record }
            return nil
        }
    }
}
