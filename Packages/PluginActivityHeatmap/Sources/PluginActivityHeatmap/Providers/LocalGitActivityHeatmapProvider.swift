import Foundation
import LumiLoggingKit
import os
import ProviderActivityHeatmap
import ProviderGit

/// Plugin-owned implementation of the shared Git activity contract.
///
/// The provider owns Git history loading and repository-keyed JSON caching;
/// settings views only consume snapshots and never talk to Git directly.
///
/// Git data comes from the `GitRepositoryReading` provider contract rather than
/// from `PluginGit` directly: plugin packages must not depend on one another.
@MainActor
final class LocalGitActivityHeatmapProvider: ActivityHeatmapProviding, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.activity-heatmap",
        category: "LocalGitActivityHeatmapProvider"
    )

    typealias CommitLoader = @Sendable (String, Int, Int) async throws -> [GitCommitLog]
    /// 缓存写入钩子：默认实现编码并原子写盘。注入点用于断言写盘所在的 executor。
    typealias CacheWriter = @Sendable (ActivityHeatmapSnapshot, URL) -> Void

    nonisolated private static let historyMonths = 12
    nonisolated private static let pageSize = 50
    nonisolated private static let cacheFileName = "activity-heatmap.json"

    private let directory: URL
    private let loadCommits: CommitLoader
    private let writeCache: CacheWriter
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private var refreshToken = 0
    private var observers: [UUID: (ActivityHeatmapEvent) -> Void] = [:]

    private(set) var currentSnapshot: ActivityHeatmapSnapshot?
    private(set) var isLoading = false

    /// - Parameter git: Git 读取契约；缺省时该 provider 无法加载提交历史，
    ///   `refresh` 会直接产出空快照（宿主未装配 `PluginGit` 时的降级路径）。
    init(
        directory: URL,
        git: (any GitRepositoryReading)? = nil,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = Date.init,
        commitLoader: CommitLoader? = nil,
        cacheWriter: CacheWriter? = nil
    ) {
        self.directory = directory
        self.calendar = calendar
        self.now = now
        self.loadCommits = commitLoader ?? { repositoryPath, limit, offset in
            guard let git else { throw GitReadError.repositoryNotFound(path: repositoryPath) }
            return try await git.log(atPath: repositoryPath, count: limit, skip: offset)
        }
        self.writeCache = cacheWriter ?? { snapshot, directory in
            Self.persist(snapshot, in: directory)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func refresh(for repositoryURL: URL?) {
        refreshToken &+= 1
        let token = refreshToken
        guard let repositoryURL else {
            setSnapshot(nil)
            setLoading(false)
            return
        }

        let repository = repositoryURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: repository.path) else {
            setSnapshot(nil)
            setLoading(false)
            return
        }

        setSnapshot(loadCachedSnapshot(for: repository))
        setLoading(currentSnapshot == nil)

        let loadCommits = self.loadCommits
        let calendar = self.calendar
        let now = self.now()
        let directory = self.directory
        let writeCache = self.writeCache
        Task { [weak self] in
            do {
                // Git I/O 之后的聚合与缓存写入同样不能留在主线程：`nonisolated static`
                // 只是解除隔离声明，从主 actor 的 Task 里同步调用仍在主 actor 上执行。
                // 整段（分页加载 → 日期解析 → 按天聚合 → JSON 编码 → 原子写盘）
                // 放进 detached 任务，主线程只做 token 校验与状态发布（#1203）。
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    let dates = try await Self.loadRecentCommitDates(
                        repositoryPath: repository.path,
                        now: now,
                        calendar: calendar,
                        loadCommits: loadCommits
                    )
                    let snapshot = Self.makeSnapshot(
                        repositoryPath: repository.path,
                        commitDates: dates,
                        calendar: calendar,
                        now: now
                    )
                    writeCache(snapshot, directory)
                    return snapshot
                }.value
                guard let self, token == self.refreshToken else { return }
                self.setSnapshot(snapshot)
                self.setLoading(false)
            } catch {
                guard let self, token == self.refreshToken else { return }
                Self.logger.error(
                    "Git activity refresh failed for \(repository.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                self.setLoading(false)
            }
        }
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (ActivityHeatmapEvent) -> Void
    ) -> any ActivityHeatmapObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    private func setSnapshot(_ snapshot: ActivityHeatmapSnapshot?) {
        guard currentSnapshot != snapshot else { return }
        currentSnapshot = snapshot
        notify(.snapshotChanged)
    }

    private func setLoading(_ value: Bool) {
        guard isLoading != value else { return }
        isLoading = value
        notify(.loadingChanged)
    }

    private func notify(_ event: ActivityHeatmapEvent) {
        observers.values.forEach { $0(event) }
    }

    /// 分页加载 12 个月内的提交，**每个提交的日期只解析一次**并把解析结果带到聚合阶段。
    ///
    /// 旧实现返回 `[GitCommitLog]`，过滤时解析一次、判断是否越界再解析一次、
    /// `makeSnapshot` 聚合时又解析一次；每次解析都会新建一个 `ISO8601DateFormatter`。
    /// 直接返回 `[Date]` 让后续阶段零解析（#1203）。
    nonisolated static func loadRecentCommitDates(
        repositoryPath: String,
        now: Date,
        calendar: Calendar,
        loadCommits: CommitLoader
    ) async throws -> [Date] {
        guard let cutoff = calendar.date(byAdding: .month, value: -historyMonths, to: now) else { return [] }

        var offset = 0
        var dates: [Date] = []
        while true {
            let page = try await loadCommits(repositoryPath, pageSize, offset)
            var reachedCutoff = false
            for commit in page {
                let parsed = date(from: commit.date) ?? .distantPast
                guard parsed >= cutoff else {
                    reachedCutoff = true
                    continue
                }
                dates.append(parsed)
            }
            offset += page.count
            if page.isEmpty || page.count < pageSize || reachedCutoff {
                break
            }
        }
        return dates
    }

    nonisolated static func makeSnapshot(
        repositoryPath: String,
        commitDates: [Date],
        calendar: Calendar,
        now: Date,
        generatedAt: Date? = nil
    ) -> ActivityHeatmapSnapshot {
        let counts = commitDates.reduce(into: [Date: Int]()) { result, date in
            result[calendar.startOfDay(for: date), default: 0] += 1
        }
        return ActivityHeatmapSnapshot(
            repositoryPath: URL(fileURLWithPath: repositoryPath).standardizedFileURL.path,
            generatedAt: generatedAt ?? now,
            days: counts.map { ActivityHeatmapDay(date: $0.key, commitCount: $0.value) }
        )
    }

    nonisolated private static func date(from value: String) -> Date? {
        GitDateFormatting.date(from: value)
    }

    nonisolated private static func cacheURL(in directory: URL, for repository: URL) -> URL {
        let encodedPath = Data(repository.standardizedFileURL.path.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return directory
            .appendingPathComponent(encodedPath, isDirectory: true)
            .appendingPathComponent(cacheFileName)
    }

    private func loadCachedSnapshot(for repository: URL) -> ActivityHeatmapSnapshot? {
        let url = Self.cacheURL(in: directory, for: repository)
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(ActivityHeatmapSnapshot.self, from: data),
              snapshot.repositoryPath == repository.standardizedFileURL.path else { return nil }
        return snapshot
    }

    /// 编码并原子写入缓存。在后台 executor 上调用，不占主线程（#1203）。
    nonisolated private static func persist(_ snapshot: ActivityHeatmapSnapshot, in directory: URL) {
        let url = cacheURL(in: directory, for: URL(fileURLWithPath: snapshot.repositoryPath))
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        } catch {
            logger.error("Failed to persist Git activity cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    private final class ObserverHandle: ActivityHeatmapObserverHandle {
        private let onCancel: () -> Void
        private var isCancelled = false

        init(onCancel: @escaping () -> Void) {
            self.onCancel = onCancel
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            onCancel()
        }
    }
}
