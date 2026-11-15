import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #1244：取消 Git 刷新只取消了外层 Task，真正的采集跑在未持有句柄的
/// `Task.detached` 里。过期采集仍会排在共享串行 Git 队列前面并跑完整条命令链，
/// 把当前项目的状态刷新挡在后面。
///
/// 期望：排队前与取到队列后都拒绝过期采集，子进程之间与轮询期间检查取消，
/// 协调器持有 worker 句柄并在 stop()/切换项目时真正取消它。
///
/// 门闩会占住共享串行队列并阻塞协作线程，必须串行执行。
@MainActor
@Suite("Git 采集取消", .serialized)
struct GitStatusCaptureCancellationTests {

    @Test("已取消的采集在进入串行队列前就被拒绝")
    func cancelledCaptureIsRejectedBeforeQueueing() throws {
        let root = try makeRepository()
        defer { try? FileManager.default.removeItem(at: root) }

        let cancellation = GitCaptureCancellation()
        cancellation.cancel()
        let counter = CheckCounter()

        let snapshot = GitStatusProvider().captureSnapshot(projectRootPath: root.path) {
            counter.record()
            return cancellation.isCancelled
        }

        #expect(snapshot == nil)
        #expect(counter.count == 1, "只应做排队前的一次检查，不能进入队列或启动 git 子进程")
    }

    @Test("排队期间被取消的采集取到队列后立即放弃")
    func captureCancelledWhileQueuedIsRejectedOnAcquire() async throws {
        let root = try makeRepository()
        defer { try? FileManager.default.removeItem(at: root) }

        let gate = GitQueueGate()
        gate.hold()
        defer { gate.release() }
        gate.waitUntilHeld()

        let cancellation = GitCaptureCancellation()
        let counter = CheckCounter()
        let provider = GitStatusProvider()
        let path = root.path
        let capture = Task.detached(priority: .userInitiated) {
            provider.captureSnapshot(projectRootPath: path) {
                counter.record()
                return cancellation.isCancelled
            }
        }

        // 采集已通过排队前检查，正阻塞在 queue.sync 上。
        #expect(await waitUntil { counter.count >= 1 })
        cancellation.cancel()
        gate.release()

        let snapshot = await capture.value
        #expect(snapshot == nil)
        #expect(counter.count == 2, "取到队列后应立刻放弃，不再启动 git 子进程")
    }

    @Test("采集在子进程之间检查取消，不再跑完后续命令")
    func captureAbortsBetweenSubprocesses() throws {
        let root = try makeRepository()
        defer { try? FileManager.default.removeItem(at: root) }

        // 前 3 次检查放行（排队前、取到队列后、首个子进程启动前），之后一律取消。
        let counter = CheckCounter()
        let snapshot = GitStatusProvider().captureSnapshot(projectRootPath: root.path) {
            counter.record()
            return counter.count > 3
        }
        #expect(snapshot == nil, "取消后必须放弃采集，而不是返回过期快照")

        let control = GitStatusProvider().captureSnapshot(projectRootPath: root.path)
        #expect(control?.entriesByRelativePath["tracked.txt"]?.status == .modified)
    }

    @Test("子进程轮询期间取消会立即终止 git，而不是等满超时")
    func cancellingDuringSubprocessTerminatesGitEarly() async throws {
        let root = try makeRepository(untrackedFileCount: 12_000)
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = GitStatusProvider(commandTimeout: 15)
        let path = root.path
        let start = Date()
        let cancelDeadline = start.addingTimeInterval(0.05)
        let capture = Task.detached(priority: .userInitiated) {
            provider.captureSnapshot(projectRootPath: path) { Date() >= cancelDeadline }
        }

        let snapshot = await capture.value
        let elapsed = Date().timeIntervalSince(start)

        #expect(snapshot == nil, "取消后必须放弃采集")
        #expect(elapsed < 5, "不能等满 15s 子进程超时，实际 \(elapsed)s")
    }

    @MainActor
    @Test("stop() 会取消在途的 Git 采集 worker")
    func stopCancelsInFlightGitCapture() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let gate = GitQueueGate()
        gate.hold()
        defer { gate.release() }
        gate.waitUntilHeld()

        let coordinator = RefreshCoordinator(gitStatusEnabled: true)
        coordinator.setProjectRootPath(root.path)
        #expect(await waitUntil { coordinator.gitStatusWorkerTask != nil })
        let worker = try #require(coordinator.gitStatusWorkerTask)

        coordinator.stop()

        #expect(worker.isCancelled, "只取消外层 Task 停不掉排队中的采集")
    }

    @MainActor
    @Test("切换项目会取消上一个项目的 Git 采集 worker")
    func projectSwitchCancelsPreviousGitCapture() async throws {
        let oldRoot = try makeTemporaryDirectory()
        let newRoot = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: oldRoot)
            try? FileManager.default.removeItem(at: newRoot)
        }

        let gate = GitQueueGate()
        gate.hold()
        defer { gate.release() }
        gate.waitUntilHeld()

        let coordinator = RefreshCoordinator(gitStatusEnabled: true)
        coordinator.setProjectRootPath(oldRoot.path)
        #expect(await waitUntil { coordinator.gitStatusWorkerTask != nil })
        let oldWorker = try #require(coordinator.gitStatusWorkerTask)

        coordinator.setProjectRootPath(newRoot.path)

        #expect(oldWorker.isCancelled, "旧项目的采集必须让位给当前项目")
    }
}

// MARK: - Fixtures

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-git-cancel-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// 建一个含已修改跟踪文件的真实仓库；`untrackedFileCount` 用于拖慢 `git status`。
private func makeRepository(untrackedFileCount: Int = 0) throws -> URL {
    let root = try makeTemporaryDirectory()
    try runGitForCancellationTest(["init", "-q"], in: root)
    try runGitForCancellationTest(["config", "user.email", "test@example.com"], in: root)
    try runGitForCancellationTest(["config", "user.name", "Test"], in: root)

    let tracked = root.appendingPathComponent("tracked.txt")
    try Data("original\n".utf8).write(to: tracked)
    try runGitForCancellationTest(["add", "tracked.txt"], in: root)
    try runGitForCancellationTest(["commit", "-q", "-m", "init"], in: root)
    try Data("modified\n".utf8).write(to: tracked)

    for index in 0..<untrackedFileCount {
        let file = root.appendingPathComponent("untracked-\(index).txt")
        try Data("untracked\n".utf8).write(to: file)
    }
    return root
}

private func runGitForCancellationTest(_ arguments: [String], in directory: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git"] + arguments
    process.currentDirectoryURL = directory
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
}

// MARK: - Test Doubles

private final class CheckCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func record() {
        lock.lock(); defer { lock.unlock() }
        value += 1
    }
}

/// 占住共享串行 Git 队列，让采集停在 `queue.sync` 上以便构造「排队期间被取消」。
private final class GitQueueGate: @unchecked Sendable {
    private let released = DispatchSemaphore(value: 0)
    private let entered = DispatchSemaphore(value: 0)

    func hold() {
        GitAccessCoordinator.queue.async { [released, entered] in
            entered.signal()
            // 兜底超时：断言失败时也不会长期占住其他用例共用的串行队列。
            _ = released.wait(timeout: .now() + 5)
        }
    }

    func waitUntilHeld() {
        _ = entered.wait(timeout: .now() + 5)
    }

    func release() {
        released.signal()
    }
}

@MainActor
private func waitUntil(
    timeout: TimeInterval = 2,
    _ condition: () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return condition()
}