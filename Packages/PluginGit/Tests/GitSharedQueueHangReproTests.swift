import Foundation
import Testing
@testable import GitPlugin

/// 回归测试：多会话并发执行 Git 操作时的隔离性、可取消性与有界等待。
///
/// ## 背景（历史 bug）
///
/// 旧实现把所有 libgit2 操作经 `GitAsyncBridge` 串行化到**全局唯一**队列，
/// 且无超时、不可取消。一次卡死的 git 调用（index.lock 被外部进程长期持有 /
/// 网络卷 IO 卡死等）会让**所有对话**的 git_status / git_log / git_show …
/// 无限排队——即线上观察到的「多个对话都处于等待状态，半小时还在等」；
/// 队列内重入 `queue.sync` 还会永久死锁整个 Git 通道。
///
/// ## 修复后的契约（本套件看守）
///
/// 1. **隔离**：单个仓库的卡死调用不阻塞其它仓库的 Git 操作。
/// 2. **可取消**：排在同一仓库队列后面的调用可通过 `Task.cancel()` 立即解除。
/// 3. **有界等待**：排队 + 执行超过 `timeout` 即抛错返回，不再无限等。
/// 4. **无重入死锁**：body 内对该队列调用 `sync` 不再死锁。
///
/// 运行方式：
/// ```bash
/// cd Packages/PluginGit && swift test --filter GitSharedQueueHangReproTests
/// ```

// MARK: - 辅助

private final class CompletionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func mark() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

@inline(__always)
private func blockSleep(_ seconds: TimeInterval) {
    if seconds <= 0 { return }
    let sem = DispatchSemaphore(value: 0)
    _ = sem.wait(timeout: .now() + seconds)
}

/// `DispatchSemaphore.wait` 在 Swift 6 中标记为 noasync；
/// 用同步辅助函数包装后再从 async 用例中调用。
@inline(__always)
private func semWait(_ sem: DispatchSemaphore, timeout: TimeInterval) -> Bool {
    sem.wait(timeout: .now() + timeout) == .success
}

/// 轮询等待条件成立。刻意不用 `withTaskGroup`（结构化并发会在作用域退出时
/// 等待所有子任务，被挂死的子任务会把测试本身也挂死）。
@inline(__always)
private func waitUntil(timeout: TimeInterval, _ condition: @escaping () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        blockSleep(0.05)
    }
    return condition()
}

/// 创建一个临时目录，用作独立的“仓库”串行域（非 git 目录也能快速返回/抛错）。
private func makeTempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-git-hang-repro-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

/// 模拟一次卡死的 libgit2 调用：占住 `dir` 所在串行域直到 `blocker` 被放行。
/// 返回"占位已生效"的信号量。
private func occupySerialDomain(
    of dir: URL,
    blocker: DispatchSemaphore
) -> DispatchSemaphore {
    let entered = DispatchSemaphore(value: 0)
    Task.detached {
        _ = try? await GitAsyncBridge.perform(on: GitService.gitQueue(for: dir.path)) {
            entered.signal()
            blocker.wait()
            return 0
        }
    }
    return entered
}

// MARK: - 回归套件

@Suite("Git shared-queue hang regression", .serialized)
struct GitSharedQueueHangReproTests {

    // MARK: 契约 1：一个仓库卡死，不连坐其它仓库的会话

    @Test("a hung call on one repository does not block other repositories")
    func hungCallOnOneRepositoryDoesNotBlockOthers() async throws {
        let blocker = DispatchSemaphore(value: 0)
        let hungDir = try makeTempDir()
        let freeDir = try makeTempDir()
        defer {
            blocker.signal()
            try? FileManager.default.removeItem(at: hungDir)
            try? FileManager.default.removeItem(at: freeDir)
        }

        let entered = occupySerialDomain(of: hungDir, blocker: blocker)
        #expect(semWait(entered, timeout: 5), "占位调用应进入串行域")

        let completions = CompletionBox()

        // 三个「对话」并发发起不同的 git 工具调用（目标仓库未被占住）。
        Task.detached {
            _ = try? await GitService.shared.getStatus(path: freeDir.path)
            completions.mark()
        }
        Task.detached {
            _ = try? await GitService.shared.getLog(
                path: freeDir.path, count: 10, branch: nil, file: nil
            )
            completions.mark()
        }
        Task.detached {
            _ = try? await GitService.shared.getCommitChangedFiles(path: freeDir.path, hash: "HEAD")
            completions.mark()
        }

        let finished = waitUntil(timeout: 3) { completions.value == 3 }
        #expect(
            finished,
            "其它仓库的 3 个并发 git 调用应 3 秒内全部结束，实际仅 \(completions.value)/3 完成 → 隔离失效"
        )
    }

    // MARK: 契约 2：排队调用可取消 —— 点「停止」立即生效

    @Test("a queued call on a busy repository can be cancelled promptly")
    func queuedCallOnBusyRepositoryIsCancellable() async throws {
        let blocker = DispatchSemaphore(value: 0)
        let dir = try makeTempDir()
        defer {
            blocker.signal()
            try? FileManager.default.removeItem(at: dir)
        }

        let entered = occupySerialDomain(of: dir, blocker: blocker)
        #expect(semWait(entered, timeout: 5), "占位调用应进入串行域")

        let finished = CompletionBox()
        let callTask = Task.detached {
            _ = try? await GitService.shared.getStatus(path: dir.path)
            finished.mark()
        }

        // 等待调用进入排队状态后请求取消（ToolManager 的「停止」即 Task.cancel()）。
        blockSleep(0.3)
        callTask.cancel()

        let released = waitUntil(timeout: 2) { finished.value == 1 }
        #expect(
            released,
            "取消后 git 调用应 2 秒内结束，实际仍在等待 → 取消无效"
        )
    }

    // MARK: 契约 3：有界等待 —— 超时抛错而非无限排队

    @Test("a queued call times out instead of waiting forever")
    func queuedCallTimesOutInsteadOfWaitingForever() async throws {
        let blocker = DispatchSemaphore(value: 0)
        let dir = try makeTempDir()
        defer {
            blocker.signal()
            try? FileManager.default.removeItem(at: dir)
        }

        let entered = occupySerialDomain(of: dir, blocker: blocker)
        #expect(semWait(entered, timeout: 5), "占位调用应进入串行域")

        let finished = CompletionBox()
        Task.detached {
            do {
                _ = try await GitAsyncBridge.perform(
                    on: GitService.gitQueue(for: dir.path),
                    timeout: 1
                ) { 0 }
            } catch is GitAsyncBridgeError {
                finished.mark()
            } catch {
                finished.mark() // 取消等其它放弃路径同样算“有界返回”
            }
        }

        let bounded = waitUntil(timeout: 4) { finished.value == 1 }
        #expect(
            bounded,
            "超时 1 秒的调用应在 4 秒内抛错返回，实际仍在等待 → 无界等待"
        )
    }

    // MARK: 契约 4：body 内重入 queue.sync 不死锁

    @Test("nested queue.sync inside the body must not deadlock")
    func nestedQueueSyncInsideBodyDoesNotDeadlock() {
        let queue = DispatchQueue(label: "com.lumi.tests.git-hang-repro.nested")

        let finished = CompletionBox()
        Task.detached {
            _ = try? await GitAsyncBridge.perform(on: queue) {
                queue.sync { } // 旧实现在队列线程上执行 body，此重入会永久死锁
                return 0
            }
            finished.mark()
        }

        let completed = waitUntil(timeout: 3) { finished.value == 1 }
        #expect(
            completed,
            "body 内重入 queue.sync 不应死锁，实际永久挂起 → 重入死锁"
        )
    }
}
