import Foundation
import Dispatch
import ProviderGitRepositoryWatch
import Testing
@testable import PluginGitRepositoryWatch

// MARK: - 夹具

private struct GitFixture {
    let projectURL: URL
    let gitDirectory: URL
}

private func makeGitFixture(label: String) throws -> GitFixture {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("GitSnapshotOffMain-\(label)-\(UUID().uuidString)", isDirectory: true)
    let projectURL = root.appendingPathComponent("repo", isDirectory: true)
    let gitDirectory = projectURL.appendingPathComponent(".git", isDirectory: true)
    try FileManager.default.createDirectory(
        at: gitDirectory.appendingPathComponent("refs/heads"),
        withIntermediateDirectories: true
    )
    try "ref: refs/heads/main\n".write(
        to: gitDirectory.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8
    )
    try "index-content".write(
        to: gitDirectory.appendingPathComponent("index"), atomically: true, encoding: .utf8
    )
    try "abc123\n".write(
        to: gitDirectory.appendingPathComponent("refs/heads/main"), atomically: true, encoding: .utf8
    )
    return GitFixture(projectURL: projectURL, gitDirectory: gitDirectory)
}

/// 可跨并发边界写入的标记盒（快照读取器是 `@Sendable`，在后台线程调用）。
private final class ThreadBox: @unchecked Sendable {
    var sawMainThread: Bool?
}

private final class FlagBox: @unchecked Sendable {
    var value = false
}

// MARK: - 回归 #1271

/// 回归 #1271：常驻 Git 监听每次 `.git` 变化都在主线程读整个 index 并逐字节哈希、
/// 枚举并哈希全部 refs。修复把快照读取移到后台任务，只在写回时做身份校验。
@Suite("Git 快照 off-main（issue #1271）")
@MainActor
struct GitSnapshotOffMainTests {

    @Test("快照读取在后台线程执行，不占主线程")
    func snapshotReadsOffMain() async throws {
        let fx = try makeGitFixture(label: "offmain")
        defer { try? FileManager.default.removeItem(at: fx.projectURL.deletingLastPathComponent()) }

        let box = ThreadBox()
        let provider = GitRepositoryWatchProvider(workingTreeChangeThrottle: 2) { url in
            // 同步读取器在后台任务里被调用，这里可以合法检查线程。
            box.sawMainThread = Thread.isMainThread
            return GitDirectoryResolver.readSnapshot(gitDirectory: url)
        }
        defer { provider.stopWatching() }

        provider.startWatching(repositoryURL: fx.projectURL)

        let recorded = await waitUntil(timeout: 5) { box.sawMainThread != nil }
        #expect(recorded, "初始基线快照应触发后台读取")
        #expect(box.sawMainThread == false, "快照读取必须在后台线程，而不是主线程")
    }

    @Test("切换仓库后，旧仓库晚到的快照不覆盖新状态、不广播变更")
    func staleSnapshotDoesNotOverrideAfterSwitch() async throws {
        let fxA = try makeGitFixture(label: "staleA")
        let fxB = try makeGitFixture(label: "staleB")
        defer {
            try? FileManager.default.removeItem(at: fxA.projectURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: fxB.projectURL.deletingLastPathComponent())
        }

        let gate = DispatchSemaphore(value: 0)
        let aEntered = FlagBox()
        // A 的读取被门闩阻塞，确保它在切换到 B 之后才返回；B 立即返回。
        let provider = GitRepositoryWatchProvider(workingTreeChangeThrottle: 2) { url in
            if url.path.contains("staleA") {
                aEntered.value = true
                gate.wait()
            }
            return GitDirectoryResolver.readSnapshot(gitDirectory: url)
        }

        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer {
            handle.cancel()
            provider.stopWatching()
        }

        provider.startWatching(repositoryURL: fxA.projectURL)
        // 等 A 的后台读取真正进入阻塞，构造「旧请求晚到」。
        let entered = await waitUntil(timeout: 5) { aEntered.value }
        #expect(entered, "A 的后台读取应已进入门闩")

        provider.startWatching(repositoryURL: fxB.projectURL)
        #expect(provider.watchingRepositoryURL?.standardizedFileURL == fxB.projectURL.standardizedFileURL)

        // 放行 A 的晚到快照。
        gate.signal()
        try await Task.sleep(for: .milliseconds(300))

        #expect(
            provider.watchingRepositoryURL?.standardizedFileURL == fxB.projectURL.standardizedFileURL,
            "晚到的旧快照不得把监听目标改回 A"
        )
        let changeEvents = events.filter {
            switch $0 {
            case .headChanged, .indexChanged, .stashChanged, .refsChanged: return true
            default: return false
            }
        }
        #expect(changeEvents.isEmpty, "旧仓库晚到快照不应广播任何变更")
    }

    /// 轮询等待条件成立，避免依赖固定 sleep 时长。
    private func waitUntil(
        timeout: TimeInterval,
        poll: TimeInterval = 0.05,
        _ condition: @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: UInt64(poll * 1_000_000_000))
        }
        return condition()
    }
}