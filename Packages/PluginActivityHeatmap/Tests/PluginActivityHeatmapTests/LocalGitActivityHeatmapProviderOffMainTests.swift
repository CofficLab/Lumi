import Foundation
import ProviderGit
import ProviderActivityHeatmap
import Testing
@testable import PluginActivityHeatmap

/// Git I/O 完成之后的聚合与缓存写入不得留在主 actor 上（回归 #1203）。
///
/// 旧实现 `await loadRecentCommits(...)` 之后直接在主 actor 的 Task 里同步调用
/// `makeSnapshot` 与 `persist`：`nonisolated static` 只是解除隔离声明，
/// 同步调用并不会换 executor，于是「按天聚合 + JSON 编码 + 原子写盘」
/// 整段压在主线程序列上，仓库刷新时 UI 正好在等这份数据。
///
/// 这里锁住两件事：加载阶段把解析好的日期带到聚合阶段（不再重复解析），
/// 以及聚合/写盘所在的 executor 不是主 actor。
@MainActor
@Suite("Git activity 聚合与缓存写入的 executor", .serialized)
struct LocalGitActivityHeatmapProviderOffMainTests {

    // MARK: - 替身

    /// 记录缓存写入所在线程，并可选地把写入挡住一小段时间。
    ///
    /// 等待方必须异步轮询：在 MainActor 上同步 wait 会挡住被测任务本身，
    /// 让「主 actor 是否空闲」的断言失去意义。
    private final class WriterProbe: @unchecked Sendable {
        private let lock = NSLock()
        private let release = DispatchSemaphore(value: 0)
        private var entered = false
        private var mainThreadHits = 0
        private var written: ActivityHeatmapSnapshot?
        private let gate: Bool

        init(gate: Bool) {
            self.gate = gate
        }

        var hasEntered: Bool { lock.withLock { entered } }
        var sawMainThread: Bool { lock.withLock { mainThreadHits > 0 } }
        var snapshot: ActivityHeatmapSnapshot? { lock.withLock { written } }

        func record(_ snapshot: ActivityHeatmapSnapshot) {
            lock.withLock {
                entered = true
                written = snapshot
                if Thread.isMainThread { mainThreadHits += 1 }
            }
            guard gate else { return }
            // 安全网：断言失败也不能把后台 worker 永久挂住。
            _ = release.wait(timeout: .now() + 5)
        }

        func open() { release.signal() }
    }

    private func waitUntilEntered(_ probe: WriterProbe) async -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if probe.hasEntered { return true }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        return probe.hasEntered
    }

    // MARK: - executor

    @Test("缓存写入不在主 actor 上执行")
    func cacheWriteRunsOffMainActor() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = root.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)

        let probe = WriterProbe(gate: false)
        let provider = LocalGitActivityHeatmapProvider(
            directory: root.appendingPathComponent("cache", isDirectory: true),
            calendar: gregorianUTC(),
            now: { date("2025-08-01T00:00:00Z") },
            commitLoader: { _, _, _ in
                [makeCommit(hash: "c0", date: "2025-07-31T12:00:00Z")]
            },
            cacheWriter: { snapshot, _ in probe.record(snapshot) }
        )

        provider.refresh(for: repository)
        #expect(await waitUntilEntered(probe))
        #expect(probe.sawMainThread == false, "缓存写入仍在主 actor 上执行")

        await waitForRefresh(provider)
        #expect(provider.isLoading == false)
        // 写盘钩子拿到的快照与最终发布的是同一份：聚合确实在写盘之前完成。
        #expect(probe.snapshot == provider.currentSnapshot)
        #expect(provider.currentSnapshot?.days.map(\.commitCount) == [1])
    }

    @Test("缓存写入被挡住时主 actor 仍能继续跳板")
    func mainActorStaysResponsiveWhileCacheWriteIsBlocked() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = root.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)

        let probe = WriterProbe(gate: true)
        let provider = LocalGitActivityHeatmapProvider(
            directory: root.appendingPathComponent("cache", isDirectory: true),
            calendar: gregorianUTC(),
            now: { date("2025-08-01T00:00:00Z") },
            commitLoader: { _, _, _ in
                [makeCommit(hash: "c0", date: "2025-07-31T12:00:00Z")]
            },
            cacheWriter: { snapshot, _ in probe.record(snapshot) }
        )

        provider.refresh(for: repository)
        // 能轮询到「已进入写盘」本身就说明主 actor 没被那段工作占住。
        #expect(await waitUntilEntered(probe))
        #expect(probe.sawMainThread == false)

        // 写盘仍被挡住时，主 actor 上的其它工作照常推进。
        var hops = 0
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 1_000_000)
            hops += 1
        }
        #expect(hops == 20)
        #expect(provider.isLoading, "写盘未完成前不该提前结束 loading")

        probe.open()
        await waitForRefresh(provider)
        #expect(provider.isLoading == false)
        #expect(probe.snapshot == provider.currentSnapshot)
    }

    // MARK: - 日期只解析一次并带到聚合阶段

    @Test("加载阶段返回解析好的日期，越界即停止分页")
    func loadingCarriesParsedDatesForward() async throws {
        let calendar = gregorianUTC()
        let now = date("2025-08-01T00:00:00Z")
        let recent = now.addingTimeInterval(-86_400)
        let ancient = date("2020-01-01T00:00:00Z")

        let firstPage = (0..<50).map { makeCommit(hash: "p0-\($0)", date: dateString(recent)) }
        // 第二页混入一条越界提交：分页必须就此停止，且越界提交不进入结果。
        let secondPage = (0..<49).map { makeCommit(hash: "p1-\($0)", date: dateString(recent)) }
            + [makeCommit(hash: "old", date: dateString(ancient))]
        let calls = PageCalls()

        let dates = try await LocalGitActivityHeatmapProvider.loadRecentCommitDates(
            repositoryPath: "/tmp/project",
            now: now,
            calendar: calendar,
            loadCommits: { _, limit, offset in
                await calls.record(limit: limit, offset: offset)
                if offset == 0 { return firstPage }
                if offset == 50 { return secondPage }
                return []
            }
        )

        #expect(dates.count == 99)
        #expect(dates.allSatisfy { $0 == recent })
        #expect(await calls.requests() == [PageRequest(limit: 50, offset: 0), PageRequest(limit: 50, offset: 50)])

        // 聚合阶段不再接触字符串日期：直接按天分组。
        let snapshot = LocalGitActivityHeatmapProvider.makeSnapshot(
            repositoryPath: "/tmp/project",
            commitDates: dates,
            calendar: calendar,
            now: now
        )
        #expect(snapshot.days.map(\.commitCount) == [99])
    }

    // MARK: - Helpers

    nonisolated private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    nonisolated private func gregorianUTC() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    nonisolated private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    nonisolated private func dateString(_ value: Date) -> String {
        ISO8601DateFormatter().string(from: value)
    }

    private func waitForRefresh(_ provider: LocalGitActivityHeatmapProvider) async {
        for _ in 0..<500 where provider.isLoading {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

private func makeCommit(hash: String, date: String) -> GitCommitLog {
    GitCommitLog(hash: hash, author: "A", email: "a@example.com", date: date, message: "commit")
}

private actor PageCalls {
    private var values: [PageRequest] = []

    func record(limit: Int, offset: Int) {
        values.append(PageRequest(limit: limit, offset: offset))
    }

    func requests() -> [PageRequest] {
        values
    }
}

private struct PageRequest: Equatable, Sendable {
    let limit: Int
    let offset: Int
}