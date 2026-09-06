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
}
