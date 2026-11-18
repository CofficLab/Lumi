import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #1243：Explorer 出现/项目切换时，`updateWatcher()` 在 SwiftUI 生命周期
/// 回调里同步执行 E 次展开目录探测、项目根枚举（包清单）与 `.git` 元数据探测。
///
/// 期望：探测全部在后台线程、过期重建被取消且不应用到 watcher、只应用最新一次结果。
///
/// 门闩会阻塞协作线程池里的线程，必须串行执行，否则多个用例同时阻塞会把池耗尽。
@MainActor
@Suite("监听列表后台探测", .serialized)
struct RefreshCoordinatorWatchProbeTests {

    @Test("展开目录与包清单探测都不在主线程执行")
    func probesRunOffMainThread() async throws {
        let root = URL(fileURLWithPath: "/tmp/lumi-watch-probe-\(UUID().uuidString)")
        let sources = root.appendingPathComponent("Sources")
        let tests = root.appendingPathComponent("Tests")
        let probe = StubWatchProbe(directories: [sources.path, tests.path])
        let watcher = RecordingWatcher()
        let coordinator = RefreshCoordinator(probe: probe, gitStatusEnabled: false)
        coordinator.attach(observer: watcher)

        coordinator.setProjectRootPath(root.path)
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 1 })
        coordinator.addExpandedPath("Sources")
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 2 })
        coordinator.addExpandedPath("Tests")
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 3 })

        probe.resetThreadFlags()
        coordinator.stop()
        coordinator.setProjectRootPath(root.path)
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 4 })

        #expect(probe.sawMainThread == false, "监听目录探测不能在主线程执行")
        #expect(probe.probedPaths.contains(sources.path))
        #expect(probe.probedPaths.contains(tests.path))
        let applied = try #require(watcher.updatedDirectorySets.last)
        #expect(applied.contains(root.standardizedFileURL))
        #expect(applied.contains(sources.standardizedFileURL))
        #expect(applied.contains(tests.standardizedFileURL))
    }

    @Test("探测期间主线程仍可响应，watcher 等新结果就绪才更新")
    func mainActorStaysResponsiveWhileProbing() async throws {
        let root = URL(fileURLWithPath: "/tmp/lumi-watch-probe-\(UUID().uuidString)")
        let sources = root.appendingPathComponent("Sources")
        let probe = StubWatchProbe(directories: [sources.path])
        let watcher = RecordingWatcher()
        let coordinator = RefreshCoordinator(probe: probe, gitStatusEnabled: false)
        coordinator.attach(observer: watcher)

        coordinator.setProjectRootPath(root.path)
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 1 })

        probe.gatedPath = sources.path
        coordinator.addExpandedPath("Sources")

        // 门闩未打开时探测仍阻塞在后台：主线程能跑到这里说明没有被同步 stat 卡住。
        #expect(await waitUntil { probe.gateReached })
        #expect(watcher.updatedDirectorySets.count == 1)

        probe.openGate()
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 2 })
        #expect(watcher.updatedDirectorySets.last?.contains(sources.standardizedFileURL) == true)
    }

    @Test("连续展开只应用最新的监听列表")
    func supersededRebuildIsNotApplied() async throws {
        let root = URL(fileURLWithPath: "/tmp/lumi-watch-probe-\(UUID().uuidString)")
        let sources = root.appendingPathComponent("Sources")
        let tests = root.appendingPathComponent("Tests")
        let probe = StubWatchProbe(directories: [sources.path, tests.path])
        let watcher = RecordingWatcher()
        let coordinator = RefreshCoordinator(probe: probe, gitStatusEnabled: false)
        coordinator.attach(observer: watcher)

        coordinator.setProjectRootPath(root.path)
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 1 })

        probe.gatedPath = sources.path
        coordinator.addExpandedPath("Sources")
        #expect(await waitUntil { probe.gateReached })

        // 上一次探测仍在途时又展开一个目录：旧结果必须作废，只应用最新列表。
        coordinator.addExpandedPath("Tests")
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 2 })

        probe.openGate()
        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(watcher.updatedDirectorySets.count == 2, "被取代的重建不能再应用一次")
        let applied = try #require(watcher.updatedDirectorySets.last)
        #expect(applied.contains(sources.standardizedFileURL))
        #expect(applied.contains(tests.standardizedFileURL))
    }

    @Test("切换项目后晚到的旧探测结果不覆盖新项目的监听列表")
    func staleProbeDoesNotOverwriteNewProject() async throws {
        let oldRoot = URL(fileURLWithPath: "/tmp/lumi-watch-probe-old-\(UUID().uuidString)")
        let oldSources = oldRoot.appendingPathComponent("Sources")
        let newRoot = URL(fileURLWithPath: "/tmp/lumi-watch-probe-new-\(UUID().uuidString)")
        let probe = StubWatchProbe(directories: [oldSources.path])
        let watcher = RecordingWatcher()
        let coordinator = RefreshCoordinator(probe: probe, gitStatusEnabled: false)
        coordinator.attach(observer: watcher)

        coordinator.setProjectRootPath(oldRoot.path)
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 1 })

        probe.gatedPath = oldSources.path
        coordinator.addExpandedPath("Sources")
        #expect(await waitUntil { probe.gateReached })

        coordinator.setProjectRootPath(newRoot.path)
        #expect(await waitUntil {
            watcher.updatedDirectorySets.last?.contains(newRoot.standardizedFileURL) == true
        })
        let countAfterSwitch = watcher.updatedDirectorySets.count

        probe.openGate()
        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(watcher.updatedDirectorySets.count == countAfterSwitch, "旧项目的探测结果必须被丢弃")
        let applied = try #require(watcher.updatedDirectorySets.last)
        #expect(applied.contains(newRoot.standardizedFileURL))
        #expect(!applied.contains(oldSources.standardizedFileURL))
    }

    @Test("stop() 之后在途探测不再重新挂载监听")
    func stoppedCoordinatorDoesNotRemountWatching() async throws {
        let root = URL(fileURLWithPath: "/tmp/lumi-watch-probe-\(UUID().uuidString)")
        let sources = root.appendingPathComponent("Sources")
        let probe = StubWatchProbe(directories: [sources.path])
        let watcher = RecordingWatcher()
        let coordinator = RefreshCoordinator(probe: probe, gitStatusEnabled: false)
        coordinator.attach(observer: watcher)

        coordinator.setProjectRootPath(root.path)
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 1 })

        probe.gatedPath = sources.path
        coordinator.addExpandedPath("Sources")
        #expect(await waitUntil { probe.gateReached })

        let stopsBeforeDisappear = watcher.stopCount
        coordinator.stop()
        probe.openGate()
        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(watcher.updatedDirectorySets.count == 1, "视图已消失，在途结果不能再挂载监听")
        #expect(watcher.stopCount == stopsBeforeDisappear + 1)
    }

    @Test(".git 元数据位置仍被纳入监听列表")
    func gitMetadataDirectoriesAreStillWatched() async throws {
        let root = URL(fileURLWithPath: "/tmp/lumi-watch-probe-\(UUID().uuidString)")
        let gitDir = root.appendingPathComponent(".git").standardizedFileURL
        let headURL = gitDir.appendingPathComponent("HEAD").standardizedFileURL
        let refsDir = gitDir.appendingPathComponent("refs").standardizedFileURL
        let refsHeadsDir = gitDir.appendingPathComponent("refs/heads").standardizedFileURL
        let logsRefsDir = gitDir.appendingPathComponent("logs/refs").standardizedFileURL
        let packedRefsURL = gitDir.appendingPathComponent("packed-refs").standardizedFileURL
        let probe = StubWatchProbe(
            directories: [gitDir.path, refsDir.path, refsHeadsDir.path, logsRefsDir.path],
            files: [headURL.path]
        )
        let watcher = RecordingWatcher()
        let coordinator = RefreshCoordinator(probe: probe, gitStatusEnabled: false)
        coordinator.attach(observer: watcher)

        coordinator.setProjectRootPath(root.path)
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 1 })

        let applied = try #require(watcher.updatedDirectorySets.last)
        #expect(applied.contains(headURL), "HEAD 是普通文件，写入/替换事件必须被监听")
        #expect(applied.contains(refsDir))
        #expect(applied.contains(refsHeadsDir), "DispatchSource 不递归，嵌套的 refs/heads 必须单独监听")
        #expect(applied.contains(logsRefsDir))
        #expect(!applied.contains(packedRefsURL), "不存在的 packed-refs 不应进入监听列表")
        #expect(!applied.contains(gitDir), "不监听整个 .git，避免无关写入造成无效刷新")
    }

    @Test("worktree 的 .git 文件解析出真实元数据目录")
    func worktreeGitFileResolvesRealGitDir() throws {
        let base = URL(fileURLWithPath: "/tmp/lumi-watch-probe-\(UUID().uuidString)")
        let projectRoot = base.appendingPathComponent("project")
        let realGitDir = base.appendingPathComponent("real-git")
        try FileManager.default.createDirectory(at: realGitDir.appendingPathComponent("refs/heads"), withIntermediateDirectories: true)
        try "ref: refs/heads/main\n".write(to: realGitDir.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        try "gitdir: \(realGitDir.path)\n".write(to: projectRoot.appendingPathComponent(".git"), atomically: true, encoding: .utf8)

        let urls = RefreshCoordinator.gitMetadataWatchURLs(
            projectRootURL: projectRoot,
            probe: DefaultWatchDirectoryProbe()
        )

        let standard = urls.map { $0.standardizedFileURL }
        #expect(standard.contains(realGitDir.appendingPathComponent("HEAD").standardizedFileURL))
        #expect(standard.contains(realGitDir.appendingPathComponent("refs/heads").standardizedFileURL))
    }

    @Test("worktree 的相对 gitdir 以项目根为基准解析")
    func relativeGitDirResolvesAgainstProjectRoot() throws {
        let base = URL(fileURLWithPath: "/tmp/lumi-watch-probe-\(UUID().uuidString)")
        let projectRoot = base.appendingPathComponent("project")
        let realGitDir = base.appendingPathComponent("real-git")
        try FileManager.default.createDirectory(at: realGitDir.appendingPathComponent("refs/heads"), withIntermediateDirectories: true)
        try "ref: refs/heads/main\n".write(to: realGitDir.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        try "gitdir: ../real-git\n".write(to: projectRoot.appendingPathComponent(".git"), atomically: true, encoding: .utf8)

        let urls = RefreshCoordinator.gitMetadataWatchURLs(
            projectRootURL: projectRoot,
            probe: DefaultWatchDirectoryProbe()
        )

        let standard = urls.map { $0.standardizedFileURL }
        #expect(standard.contains(realGitDir.appendingPathComponent("HEAD").standardizedFileURL))
        #expect(standard.contains(realGitDir.appendingPathComponent("refs/heads").standardizedFileURL))
    }

    @Test("非 Git 仓库不产生任何监听位置")
    func nonGitRootProducesEmptyWatchList() throws {
        let root = URL(fileURLWithPath: "/tmp/lumi-watch-probe-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let urls = RefreshCoordinator.gitMetadataWatchURLs(
            projectRootURL: root,
            probe: DefaultWatchDirectoryProbe()
        )

        #expect(urls.isEmpty)
    }

    @Test("不存在的展开目录不会进入监听列表")
    func missingExpandedDirectoriesAreSkipped() async throws {
        let root = URL(fileURLWithPath: "/tmp/lumi-watch-probe-\(UUID().uuidString)")
        let sources = root.appendingPathComponent("Sources")
        let probe = StubWatchProbe(directories: [sources.path])
        let watcher = RecordingWatcher()
        let coordinator = RefreshCoordinator(probe: probe, gitStatusEnabled: false)
        coordinator.attach(observer: watcher)

        coordinator.setProjectRootPath(root.path)
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 1 })
        coordinator.addExpandedPath("Sources")
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 2 })
        coordinator.addExpandedPath("Gone")
        #expect(await waitUntil { watcher.updatedDirectorySets.count == 3 })

        let applied = try #require(watcher.updatedDirectorySets.last)
        #expect(applied.contains(sources.standardizedFileURL))
        #expect(!applied.contains(root.appendingPathComponent("Gone").standardizedFileURL))
    }
}

// MARK: - Test Doubles

private final class StubWatchProbe: WatchDirectoryProbing, @unchecked Sendable {
    private let lock = NSLock()
    private let directories: Set<String>
    private let files: Set<String>
    private let manifests: [URL]
    private var paths: [String] = []
    private var mainThread = false
    private var didGate = false
    private var reached = false
    private let gate = DispatchSemaphore(value: 0)

    /// 需要门闩阻塞的探测路径；nil 表示不阻塞。
    var gatedPath: String?

    init(directories: Set<String>, files: Set<String> = [], manifests: [URL] = []) {
        self.directories = directories
        self.files = files
        self.manifests = manifests
    }

    var sawMainThread: Bool {
        lock.lock(); defer { lock.unlock() }
        return mainThread
    }

    var gateReached: Bool {
        lock.lock(); defer { lock.unlock() }
        return reached
    }

    var probedPaths: [String] {
        lock.lock(); defer { lock.unlock() }
        return paths
    }

    func resetThreadFlags() {
        lock.lock(); defer { lock.unlock() }
        mainThread = false
    }

    func openGate() {
        gate.signal()
    }

    func isDirectory(atPath path: String) -> Bool {
        lock.lock()
        recordProbe(path)
        let exists = directories.contains(path)
        let shouldGate = !didGate && path == gatedPath
        if shouldGate {
            didGate = true
            reached = true
        }
        lock.unlock()

        if shouldGate { gate.wait() }
        return exists
    }

    func fileExists(atPath path: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        recordProbe(path)
        return directories.contains(path) || files.contains(path)
    }

    private func recordProbe(_ path: String) {
        if Thread.isMainThread { mainThread = true }
        paths.append(path)
    }

    func manifestURLs(projectRootURL: URL) -> [URL] {
        lock.lock(); defer { lock.unlock() }
        if Thread.isMainThread { mainThread = true }
        return manifests
    }
}

private final class RecordingWatcher: FileTreeWatching, @unchecked Sendable {
    private(set) var updatedDirectorySets: [Set<URL>] = []
    private(set) var stopCount = 0

    func updateWatchedDirectories(_ directories: Set<URL>) {
        updatedDirectorySets.append(directories)
    }

    func stopWatching() {
        stopCount += 1
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