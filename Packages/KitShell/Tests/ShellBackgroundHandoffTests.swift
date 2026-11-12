import Darwin
import Foundation
import Testing
@testable import KitShell

/// 后台交接（foreground budget → background handoff）的行为契约。
///
/// 核心约定：**前台预算耗尽不杀进程**。进程被交给后台继续跑，调用方通过
/// `BackgroundShellHandle` 接管所有权；交接之后取消前台任务**不得**终止进程。
@Suite("Shell Background Handoff")
struct ShellBackgroundHandoffTests {

    // MARK: - 预算耗尽 → 交接

    @Test("前台预算耗尽时进程被交接给后台且仍在运行")
    func testBudgetExpiryHandsOffWithoutKillingProcess() async throws {
        let outcome = try await ShellExecutor.executeStreamingWithBackgroundHandoff(
            "sleep 30",
            options: .init(timeout: 0.5, throwsOnError: false)
        )

        guard case .backgrounded(let handle) = outcome else {
            Issue.record("预算耗尽后应返回 .backgrounded")
            return
        }

        #expect(handle.processIdentifier > 0)
        #expect(isProcessRunning(handle.processIdentifier))

        handle.terminate()
        await waitUntilNotRunning(handle.processIdentifier)
    }

    @Test("交接后进程退出码可被后台所有者读到")
    func testBackgroundHandleReportsExitCode() async throws {
        let outcome = try await ShellExecutor.executeStreamingWithBackgroundHandoff(
            "sleep 2; exit 7",
            options: .init(timeout: 0.5, throwsOnError: false)
        )

        guard case .backgrounded(let handle) = outcome else {
            Issue.record("预算耗尽后应返回 .backgrounded")
            return
        }

        let exitCode = await handle.waitForExit()
        #expect(exitCode == 7)
    }

    @Test("交接后输出继续流入回调")
    func testOutputKeepsFlowingAfterHandoff() async throws {
        let chunks = HandoffLockedBuffer()

        let outcome = try await ShellExecutor.executeStreamingWithBackgroundHandoff(
            "echo before; sleep 2; echo after",
            options: .init(timeout: 0.5, throwsOnError: false),
            onOutput: { chunk in
                chunks.append(chunk)
            }
        )

        guard case .backgrounded(let handle) = outcome else {
            Issue.record("预算耗尽后应返回 .backgrounded")
            return
        }

        // 交接之后进程仍在跑，管道读端保持打开，输出必须继续送达。
        try await Task.sleep(nanoseconds: 3_000_000_000)
        #expect(chunks.text.contains("before"))
        #expect(chunks.text.contains("after"))

        _ = await handle.waitForExit()
    }

    // MARK: - 快速命令

    @Test("预算内完成的命令仍然返回 .completed")
    func testFastCommandStillCompletes() async throws {
        let outcome = try await ShellExecutor.executeStreamingWithBackgroundHandoff(
            "echo done",
            options: .init(timeout: 5)
        )

        guard case .completed(let result) = outcome else {
            Issue.record("预算内完成应返回 .completed")
            return
        }

        #expect(result.isSuccess)
        #expect(result.stdout == "done")
    }

    // MARK: - 显式停止

    @Test("显式停止会杀掉整个进程树")
    func testExplicitStopTerminatesProcessTree() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let pidFile = tempDir.appendingPathComponent("child.pid")
        let command = "sleep 30 & echo $! > '\(pidFile.path)'; wait"

        let outcome = try await ShellExecutor.executeStreamingWithBackgroundHandoff(
            command,
            options: .init(
                shellExecutable: "/bin/zsh",
                timeout: 0.5,
                throwsOnError: false,
                terminationGracePeriod: 0.25
            )
        )

        guard case .backgrounded(let handle) = outcome else {
            Issue.record("预算耗尽后应返回 .backgrounded")
            return
        }

        try await waitForFile(pidFile)
        let childPID = try readPID(from: pidFile)

        handle.terminate()

        await waitUntilNotRunning(childPID)
        await waitUntilNotRunning(handle.processIdentifier)
        #expect(!isProcessRunning(childPID))
    }

    // MARK: - 取消语义

    @Test("前台任务在启动前被取消时不会启动进程")
    func testCancellationBeforeStartNeverLaunchesProcess() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let marker = tempDir.appendingPathComponent("launched.txt")

        let task = Task {
            try await ShellExecutor.executeStreamingWithBackgroundHandoff(
                "touch '\(marker.path)'; sleep 5",
                options: .init(timeout: 10, throwsOnError: false)
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("取消后应抛出 .cancelled")
        } catch let error as ShellError {
            guard case .cancelled = error else {
                Issue.record("错误类型不对: \(error)")
                return
            }
        }

        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    @Test("交接之后取消前台任务不会终止后台进程")
    func testCancellationAfterHandoffKeepsProcessAlive() async throws {
        let task = Task {
            try await ShellExecutor.executeStreamingWithBackgroundHandoff(
                "sleep 30",
                options: .init(timeout: 0.5, throwsOnError: false)
            )
        }

        // 等待交接完成：预算 0.5s，之后 outcome 才是 .backgrounded。
        let outcome = try await task.value

        guard case .backgrounded(let handle) = outcome else {
            Issue.record("预算耗尽后应返回 .backgrounded")
            return
        }

        // 前台任务已经结束；此后再触发取消也不应影响后台进程。
        let pid = handle.processIdentifier
        #expect(isProcessRunning(pid))

        handle.terminate()
        await waitUntilNotRunning(pid)
    }
}

// MARK: - Helpers

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("KitShellHandoffTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func waitForFile(_ url: URL, timeout: TimeInterval = 3.0) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if FileManager.default.fileExists(atPath: url.path) {
            return
        }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    Issue.record("等待文件超时: \(url.path)")
}

private func readPID(from url: URL) throws -> Int32 {
    let raw = try String(contentsOf: url, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let pid = Int32(raw) else {
        Issue.record("非法 pid: \(raw)")
        return -1
    }
    return pid
}

private func isProcessRunning(_ pid: Int32) -> Bool {
    guard pid > 0 else { return false }
    return kill(pid, 0) == 0
}

private func waitUntilNotRunning(_ pid: Int32, timeout: TimeInterval = 3.0) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if !isProcessRunning(pid) { return }
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
}

private final class HandoffLockedBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = ""

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ value: String) {
        lock.lock()
        storage += value
        lock.unlock()
    }
}
