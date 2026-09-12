import Foundation
import GitPlugin
import ProviderActivityHeatmap
import Testing
@testable import PluginActivityHeatmap

@Suite("Local Git activity refresh")
@MainActor
struct LocalGitActivityHeatmapProviderRefreshTests {
    @Test("loads recent history in pages, caches its snapshot, and cancels observers")
    func refreshLoadsAndCachesRecentHistory() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = root.appendingPathComponent("project", isDirectory: true)
        let cacheDirectory = root.appendingPathComponent("cache", isDirectory: true)
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = date("2025-08-01T00:00:00Z")
        let recent = makeCommit(hash: "recent", date: dateString(now.addingTimeInterval(-86_400)))
        let old = makeCommit(hash: "old", date: dateString(date("2024-07-31T00:00:00Z")))
        let firstPage = (0..<50).map { index in
            makeCommit(hash: "page-one-\(index)", date: recent.date)
        }
        let calls = PageCalls()
        let provider = LocalGitActivityHeatmapProvider(
            directory: cacheDirectory,
            calendar: calendar,
            now: { now },
            commitLoader: { _, limit, offset in
                await calls.record(limit: limit, offset: offset)
                if offset == 0 {
                    return firstPage
                }
                if offset == 50 {
                    return [old, recent]
                }
                return []
            }
        )

        var events: [ActivityHeatmapEvent] = []
        let observer = provider.addObserver { events.append($0) }
        provider.refresh(for: repository)
        await waitForRefresh(provider)

        #expect(provider.isLoading == false)
        #expect(provider.currentSnapshot?.repositoryPath == repository.standardizedFileURL.path)
        #expect(provider.currentSnapshot?.days.map(\.commitCount) == [51])
        #expect(await calls.requests() == [PageRequest(limit: 50, offset: 0), PageRequest(limit: 50, offset: 50)])
        #expect(events == [.loadingChanged, .snapshotChanged, .loadingChanged])

        let failingCalls = PageCalls()
        let cachedProvider = LocalGitActivityHeatmapProvider(
            directory: cacheDirectory,
            calendar: calendar,
            now: { now },
            commitLoader: { _, limit, offset in
                await failingCalls.record(limit: limit, offset: offset)
                throw TestFailure.expected
            }
        )
        cachedProvider.refresh(for: repository)
        let cachedSnapshot = try #require(cachedProvider.currentSnapshot)
        #expect(cachedSnapshot == provider.currentSnapshot)
        await waitForRequest(failingCalls)
        await waitForRefresh(cachedProvider)
        #expect(cachedProvider.currentSnapshot == cachedSnapshot)
        #expect(cachedProvider.isLoading == false)

        observer.cancel()
        provider.refresh(for: nil)
        #expect(provider.currentSnapshot == nil)
        #expect(events == [.loadingChanged, .snapshotChanged, .loadingChanged])
    }

    @Test("a failed first load always clears the loading state")
    func failedInitialLoadClearsLoading() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = root.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        let calls = PageCalls()
        let provider = LocalGitActivityHeatmapProvider(
            directory: root.appendingPathComponent("cache", isDirectory: true),
            commitLoader: { _, limit, offset in
                await calls.record(limit: limit, offset: offset)
                throw TestFailure.expected
            }
        )

        provider.refresh(for: repository)
        #expect(provider.isLoading)
        await waitForRefresh(provider)

        #expect(await calls.requests().count == 1)
        #expect(provider.currentSnapshot == nil)
        #expect(provider.isLoading == false)
    }

    @Test("ignores malformed commit dates and standardizes repository paths")
    func snapshotIgnoresMalformedDatesAndStandardizesPath() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = date("2025-08-01T12:00:00Z")
        let snapshot = LocalGitActivityHeatmapProvider.makeSnapshot(
            repositoryPath: "/tmp/project/../project",
            commits: [
                makeCommit(hash: "valid-1", date: dateString(day)),
                makeCommit(hash: "valid-2", date: "not a date"),
                makeCommit(hash: "valid-3", date: "2025-08-01 12:00:00 +0000"),
            ],
            calendar: calendar,
            now: day
        )

        #expect(snapshot.repositoryPath == "/tmp/project")
        #expect(snapshot.days.map(\.commitCount) == [2])
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func dateString(_ value: Date) -> String {
        ISO8601DateFormatter().string(from: value)
    }

    private func makeCommit(hash: String, date: String) -> GitCommitLog {
        let data = "{\"hash\":\"\(hash)\",\"author\":\"A\",\"email\":\"a@example.com\",\"date\":\"\(date)\",\"message\":\"commit\"}".data(using: .utf8)!
        return try! JSONDecoder().decode(GitCommitLog.self, from: data)
    }

    private func waitForRefresh(_ provider: LocalGitActivityHeatmapProvider) async {
        for _ in 0..<100 where provider.isLoading {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func waitForRequest(_ calls: PageCalls) async {
        for _ in 0..<100 {
            if await !calls.requests().isEmpty { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
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

private enum TestFailure: Error {
    case expected
}
