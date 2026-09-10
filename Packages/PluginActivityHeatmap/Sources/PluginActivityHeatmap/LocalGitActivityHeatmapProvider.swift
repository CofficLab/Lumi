import Foundation
import GitPlugin
import KitSuperLog
import os
import ProviderActivityHeatmap

/// Plugin-owned implementation of the shared Git activity contract.
///
/// The provider owns Git history loading and repository-keyed JSON caching;
/// settings views only consume snapshots and never talk to Git directly.
@MainActor
final class LocalGitActivityHeatmapProvider: ActivityHeatmapProviding, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.activity-heatmap",
        category: "LocalGitActivityHeatmapProvider"
    )

    typealias CommitLoader = @Sendable (String, Int, Int) async throws -> [GitCommitLog]

    nonisolated private static let historyMonths = 12
    nonisolated private static let pageSize = 50
    nonisolated private static let cacheFileName = "activity-heatmap.json"

    private let directory: URL
    private let loadCommits: CommitLoader
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private var refreshToken = 0
    private var observers: [UUID: (ActivityHeatmapEvent) -> Void] = [:]

    private(set) var currentSnapshot: ActivityHeatmapSnapshot?
    private(set) var isLoading = false

    init(
        directory: URL,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = Date.init,
        commitLoader: CommitLoader? = nil
    ) {
        self.directory = directory
        self.calendar = calendar
        self.now = now
        self.loadCommits = commitLoader ?? { repositoryPath, limit, offset in
            try await GitService.shared.getLogWithSkip(path: repositoryPath, count: limit, skip: offset)
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
        Task { [weak self] in
            do {
                let commits = try await Self.loadRecentCommits(
                    repositoryPath: repository.path,
                    now: now,
                    calendar: calendar,
                    loadCommits: loadCommits
                )
                let snapshot = Self.makeSnapshot(
                    repositoryPath: repository.path,
                    commits: commits,
                    calendar: calendar,
                    now: now
                )
                guard let self, token == self.refreshToken else { return }
                self.persist(snapshot)
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

    nonisolated private static func loadRecentCommits(
        repositoryPath: String,
        now: Date,
        calendar: Calendar,
        loadCommits: CommitLoader
    ) async throws -> [GitCommitLog] {
        guard let cutoff = calendar.date(byAdding: .month, value: -historyMonths, to: now) else { return [] }

        var offset = 0
        var commits: [GitCommitLog] = []
        while true {
            let page = try await loadCommits(repositoryPath, pageSize, offset)
            commits.append(contentsOf: page.filter { Self.date(from: $0.date) ?? .distantPast >= cutoff })
            offset += page.count
            if page.isEmpty || page.count < pageSize || page.contains(where: { (Self.date(from: $0.date) ?? .distantPast) < cutoff }) {
                break
            }
        }
        return commits
    }

    nonisolated static func makeSnapshot(
        repositoryPath: String,
        commits: [GitCommitLog],
        calendar: Calendar,
        now: Date,
        generatedAt: Date? = nil
    ) -> ActivityHeatmapSnapshot {
        let counts = commits.reduce(into: [Date: Int]()) { result, commit in
            guard let date = date(from: commit.date) else { return }
            result[calendar.startOfDay(for: date), default: 0] += 1
        }
        return ActivityHeatmapSnapshot(
            repositoryPath: URL(fileURLWithPath: repositoryPath).standardizedFileURL.path,
            generatedAt: generatedAt ?? now,
            days: counts.map { ActivityHeatmapDay(date: $0.key, commitCount: $0.value) }
        )
    }

    nonisolated private static func date(from value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        return DateParseHelper.formatHandlers.lazy.compactMap { $0.date(from: value) }.first
    }

    private func cacheURL(for repository: URL) -> URL {
        let encodedPath = Data(repository.standardizedFileURL.path.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return directory
            .appendingPathComponent(encodedPath, isDirectory: true)
            .appendingPathComponent(Self.cacheFileName)
    }

    private func loadCachedSnapshot(for repository: URL) -> ActivityHeatmapSnapshot? {
        let url = cacheURL(for: repository)
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(ActivityHeatmapSnapshot.self, from: data),
              snapshot.repositoryPath == repository.standardizedFileURL.path else { return nil }
        return snapshot
    }

    private func persist(_ snapshot: ActivityHeatmapSnapshot) {
        let url = cacheURL(for: URL(fileURLWithPath: snapshot.repositoryPath))
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        } catch {
            Self.logger.error("Failed to persist Git activity cache: \(error.localizedDescription, privacy: .public)")
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
