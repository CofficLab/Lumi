import Foundation
import Testing
@testable import ProviderGitRepositoryWatch

@MainActor
@Suite("ProviderGitRepositoryWatch")
struct ProviderGitRepositoryWatchTests {
    @Test("start is idempotent and broadcasts lifecycle events")
    func lifecycleEvents() {
        let provider = DefaultGitRepositoryWatching()
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        let repository = URL(fileURLWithPath: "/tmp/lumi-repository")
        provider.startWatching(repositoryURL: repository)
        provider.startWatching(repositoryURL: repository)
        provider.stopWatching()

        #expect(provider.watchingRepositoryURL == nil)
        #expect(events == [
            .started(repositoryURL: repository.standardizedFileURL),
            .stopped,
        ])
    }

    @Test("cancelled observers no longer receive events")
    func cancellation() {
        let provider = DefaultGitRepositoryWatching()
        var count = 0
        let handle = provider.addObserver { _ in count += 1 }
        handle.cancel()

        provider.broadcast(.workingTreeChanged)

        #expect(count == 0)
    }

    @Test("initially no repository is being watched")
    func startsNotWatching() {
        let provider = DefaultGitRepositoryWatching()
        #expect(provider.watchingRepositoryURL == nil)
    }

    @Test("stop when not watching is a no-op and does not broadcast stopped")
    func stopWhenIdleIsNoOp() {
        let provider = DefaultGitRepositoryWatching()
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        provider.stopWatching()
        provider.stopWatching()

        #expect(provider.watchingRepositoryURL == nil)
        #expect(events.isEmpty)
    }

    @Test("starting a different repository switches the watched URL and broadcasts started")
    func switchingRepositoryBroadcastsStarted() {
        let provider = DefaultGitRepositoryWatching()
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        let first = URL(fileURLWithPath: "/tmp/repo-a")
        let second = URL(fileURLWithPath: "/tmp/repo-b")
        provider.startWatching(repositoryURL: first)
        provider.startWatching(repositoryURL: second)

        #expect(provider.watchingRepositoryURL == second.standardizedFileURL)
        #expect(events == [
            .started(repositoryURL: first.standardizedFileURL),
            .started(repositoryURL: second.standardizedFileURL),
        ])
    }

    @Test("restarting after stop broadcasts started again")
    func restartAfterStopBroadcastsStarted() {
        let provider = DefaultGitRepositoryWatching()
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        let repo = URL(fileURLWithPath: "/tmp/repo")
        provider.startWatching(repositoryURL: repo)
        provider.stopWatching()
        provider.startWatching(repositoryURL: repo)

        #expect(events == [
            .started(repositoryURL: repo.standardizedFileURL),
            .stopped,
            .started(repositoryURL: repo.standardizedFileURL),
        ])
    }

    @Test("stored repository URL is the standardized form of the input")
    func storedURLIsStandardized() {
        let provider = DefaultGitRepositoryWatching()
        let repo = URL(fileURLWithPath: "/tmp/repo")
        provider.startWatching(repositoryURL: repo)
        #expect(provider.watchingRepositoryURL == repo.standardizedFileURL)
        provider.stopWatching()
    }

    @Test("starting the same standardized URL twice is a no-op")
    func restartingSameStandardizedURLIsNoOp() {
        let provider = DefaultGitRepositoryWatching()
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        let repo = URL(fileURLWithPath: "/tmp/repo").standardizedFileURL
        provider.startWatching(repositoryURL: repo)
        provider.startWatching(repositoryURL: repo)

        #expect(events == [.started(repositoryURL: repo)])
    }

    @Test("broadcast fans out to all live observers")
    func broadcastReachesAllObservers() {
        let provider = DefaultGitRepositoryWatching()
        var firstCount = 0
        var secondCount = 0
        let h1 = provider.addObserver { _ in firstCount += 1 }
        let h2 = provider.addObserver { _ in secondCount += 1 }

        provider.broadcast(.indexChanged)
        provider.broadcast(.stashChanged)

        #expect(firstCount == 2)
        #expect(secondCount == 2)
        h1.cancel()
        provider.broadcast(.refsChanged)
        #expect(firstCount == 2)
        #expect(secondCount == 3)
        h2.cancel()
    }

    @Test("double cancel is safe")
    func doubleCancelIsSafe() {
        let provider = DefaultGitRepositoryWatching()
        var count = 0
        let handle = provider.addObserver { _ in count += 1 }
        handle.cancel()
        handle.cancel()
        provider.broadcast(.workingTreeChanged)
        #expect(count == 0)
    }

    @Test("events with associated values compare by content")
    func eventAssociatedValueEquality() {
        let repo = URL(fileURLWithPath: "/tmp/repo")
        #expect(GitRepositoryWatchingEvent.started(repositoryURL: repo) == .started(repositoryURL: repo))
        #expect(
            GitRepositoryWatchingEvent.headChanged(previousHead: "a", head: "b")
            == .headChanged(previousHead: "a", head: "b")
        )
        #expect(
            GitRepositoryWatchingEvent.headChanged(previousHead: "a", head: "b")
            != .headChanged(previousHead: "a", head: "c")
        )
        #expect(GitRepositoryWatchingEvent.indexChanged == .indexChanged)
        #expect(GitRepositoryWatchingEvent.indexChanged != .stashChanged)
        #expect(GitRepositoryWatchingEvent.headChanged(previousHead: nil, head: nil)
            == .headChanged(previousHead: nil, head: nil))
    }
}
