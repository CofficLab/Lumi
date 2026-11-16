import Foundation
import ProviderIdleTime
import ProviderProject
import Testing
@testable import ProjectRAGEngine

/// idle 调度的候选扫描不得把文件系统延迟放在 MainActor 上（回归 #1251）。
///
/// 旧实现在 `@MainActor` 的 `makeCandidates` 里对**每个**已保存项目同步调用
/// `FileManager.fileExists(atPath:isDirectory:)`，而且探测发生在排除当前项目之前；
/// 成功切片后又会立刻重扫全部路径，P 个项目追赶时探测量趋向 O(P²)。
///
/// 这里锁住：探测在后台、当前项目提前排除、取消能中止探测、切换项目后旧扫描作废、
/// 以及成功切片后复用候选（不再每片重扫）。
@MainActor
@Suite("RAG idle 调度候选扫描", .serialized)
struct RAGIndexSchedulerCandidateScanTests {

    // MARK: - 替身

    @MainActor
    private final class StubProjects: ProjectProviding {
        var currentProject: ProjectInfo?
        var projects: [ProjectInfo]
        var openFileURLs: [URL] = []
        var currentFileURL: URL?

        init(currentProject: ProjectInfo? = nil, projects: [ProjectInfo]) {
            self.currentProject = currentProject
            self.projects = projects
        }

        func openProject(at path: String, reason: ProjectChangeReason) async throws {
            currentProject = ProjectInfo(name: path, path: path)
        }
        func updateCurrentFile(_ fileURL: URL?) { currentFileURL = fileURL }
        func updateOpenFiles(_ fileURLs: [URL]) { openFileURLs = fileURLs }
        func closeFile(_ fileURL: URL) { openFileURLs.removeAll { $0 == fileURL } }
        func closeProject(reason: ProjectChangeReason) async { currentProject = nil }
        func refreshProjects() async throws {}
        func synchronizeProjects(_ projects: [ProjectInfo]) { self.projects = projects }
    }

    /// 只拦第一次调用的门闩，用来稳定构造「探测仍在进行中」的窗口。
    /// 等待方必须异步轮询：在 MainActor 上同步 wait 会挡住被测 Task 自身。
    private final class ProbeGate: @unchecked Sendable {
        private let release = DispatchSemaphore(value: 0)
        private let lock = NSLock()
        private var armed = true
        private var entered = false

        var hasEntered: Bool { lock.withLock { entered } }

        func pauseFirstCall() {
            let shouldBlock = lock.withLock {
                guard armed else { return false }
                armed = false
                entered = true
                return true
            }
            guard shouldBlock else { return }
            // 安全网：断言失败也不能把后台 worker 永久挂住。
            _ = release.wait(timeout: .now() + 5)
        }

        func open() { release.signal() }
    }

    /// 记录探测线程与次数的路径探测替身。
    private final class RecordingProbe: RAGProjectPathProbing, @unchecked Sendable {
        private let lock = NSLock()
        private var paths: [String] = []
        private var mainThreadHits = 0
        private let existing: Set<String>
        private let gate: ProbeGate?

        init(existing: Set<String>, gate: ProbeGate? = nil) {
            self.existing = existing
            self.gate = gate
        }

        var probedPaths: [String] { lock.withLock { paths } }
        var sawMainThread: Bool { lock.withLock { mainThreadHits > 0 } }

        func isDirectory(atPath path: String) -> Bool {
            lock.withLock {
                paths.append(path)
                if Thread.isMainThread { mainThreadHits += 1 }
            }
            gate?.pauseFirstCall()
            return lock.withLock { existing.contains(path) }
        }
    }

    // MARK: - 装配

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-scheduler-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeScheduler(
        projects: StubProjects,
        probe: RecordingProbe,
        directory: URL
    ) -> RAGIndexScheduler {
        RAGIndexScheduler(
            projects: projects,
            idleTime: DefaultIdleTimeProviding(),
            // 不调用 initialize：状态查询会抛 notInitialized，候选按「需要索引」处理，
            // 用例因此不会触发真实索引与 embedding。
            service: RAGService(databaseDirectoryProvider: { directory }),
            stateDirectory: directory,
            pathProbe: probe
        )
    }

    private func projectInfos(_ paths: [String]) -> [ProjectInfo] {
        paths.map { ProjectInfo(name: ($0 as NSString).lastPathComponent, path: $0) }
    }

    private func waitUntilEntered(_ gate: ProbeGate) async -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if gate.hasEntered { return true }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        return gate.hasEntered
    }

    // MARK: - 探测位置与范围

    @Test("路径探测在后台执行，且只保留存在的目录")
    func probesRunOffMainActor() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = "/tmp/rag-scan-\(UUID().uuidString)"
        let existing = ["\(root)/A", "\(root)/B"]
        let missing = "\(root)/Missing"
        let projects = StubProjects(projects: projectInfos([existing[0], missing, existing[1]]))
        let probe = RecordingProbe(existing: Set(existing))
        let scheduler = makeScheduler(projects: projects, probe: probe, directory: directory)

        let candidates = await scheduler.makeCandidates()

        #expect(probe.sawMainThread == false, "路径探测仍在 MainActor 上执行")
        #expect(probe.probedPaths == [existing[0], missing, existing[1]])
        #expect(candidates.map(\.projectPath) == existing)
    }

    @Test("当前项目在探测之前就被排除")
    func currentProjectIsExcludedBeforeProbing() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = "/tmp/rag-scan-\(UUID().uuidString)"
        let paths = ["\(root)/A", "\(root)/B"]
        let projects = StubProjects(
            currentProject: ProjectInfo(name: "A", path: paths[0]),
            projects: projectInfos(paths)
        )
        let probe = RecordingProbe(existing: Set(paths))
        let scheduler = makeScheduler(projects: projects, probe: probe, directory: directory)

        let candidates = await scheduler.makeCandidates()

        #expect(probe.probedPaths == [paths[1]], "当前项目不该浪费一次文件系统探测")
        #expect(candidates.map(\.projectPath) == [paths[1]])
    }

    // MARK: - 取消与身份校验

    @Test("取消扫描会中止后续路径探测")
    func cancellingScanStopsProbing() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = "/tmp/rag-scan-\(UUID().uuidString)"
        let paths = (0..<50).map { "\(root)/P\($0)" }
        let projects = StubProjects(projects: projectInfos(paths))
        let gate = ProbeGate()
        let probe = RecordingProbe(existing: Set(paths), gate: gate)
        let scheduler = makeScheduler(projects: projects, probe: probe, directory: directory)

        let scan = Task { await scheduler.makeCandidates() }
        #expect(await waitUntilEntered(gate))
        scan.cancel()
        gate.open()

        let candidates = await scan.value
        #expect(candidates.isEmpty)
        #expect(probe.probedPaths.count <= 2, "取消后仍继续探测了 \(probe.probedPaths.count) 个路径")
    }

    @Test("探测期间切换项目，旧扫描结果整份丢弃")
    func projectSwitchDiscardsStaleScan() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = "/tmp/rag-scan-\(UUID().uuidString)"
        let paths = ["\(root)/A", "\(root)/B"]
        let projects = StubProjects(projects: projectInfos(paths))
        let gate = ProbeGate()
        let probe = RecordingProbe(existing: Set(paths), gate: gate)
        let scheduler = makeScheduler(projects: projects, probe: probe, directory: directory)

        let scan = Task { await scheduler.makeCandidates() }
        #expect(await waitUntilEntered(gate))
        // 旧请求晚到：探测还没结束，用户已经切到 A。
        projects.currentProject = ProjectInfo(name: "A", path: paths[0])
        gate.open()

        let candidates = await scan.value
        #expect(candidates.isEmpty, "切换项目后仍采用了上一次扫描的候选")
    }

    // MARK: - 追赶节奏

    @Test("成功切片后复用候选，缓存空了才重扫路径")
    func successfulSliceReusesCandidates() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = "/tmp/rag-scan-\(UUID().uuidString)"
        let paths = ["\(root)/A", "\(root)/B", "\(root)/C"]
        let projects = StubProjects(projects: projectInfos(paths))
        let probe = RecordingProbe(existing: Set(paths))
        let scheduler = makeScheduler(projects: projects, probe: probe, directory: directory)

        let first = await scheduler.candidatesForNextSlice()
        #expect(first.count == 3)
        #expect(probe.probedPaths.count == 3)

        // 未消费任何候选：下一片直接复用，不再探测。
        let second = await scheduler.candidatesForNextSlice()
        #expect(second == first)
        #expect(probe.probedPaths.count == 3)

        scheduler.consumeCandidate(first[0].projectPath)
        let third = await scheduler.candidatesForNextSlice()
        #expect(third.count == 2)
        #expect(probe.probedPaths.count == 3)

        // 候选耗尽才重扫：P 个项目各成功一片只触发一次全量探测，而不是 P 次。
        for candidate in third {
            scheduler.consumeCandidate(candidate.projectPath)
        }
        let fourth = await scheduler.candidatesForNextSlice()
        #expect(fourth.count == 3)
        #expect(probe.probedPaths.count == 6)
    }
}