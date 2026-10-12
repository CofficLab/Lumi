import Foundation
import ProviderGitRepositoryWatch

/// 基于 FSEventStream 的 `GitRepositoryWatching` 实现。
@MainActor
public final class GitRepositoryWatchProvider: GitRepositoryWatching {
    public private(set) var watchingRepositoryURL: URL?

    private var watchedGitDirectory: String?
    private var lastSnapshot: GitDirectorySnapshot?
    private var gitWatcher: GitDirectoryWatcher?
    private var workingTreeWatcher: WorkingTreeWatcher?
    private var gitDebounceTask: Task<Void, Never>?
    private var workingTreeDebounceTask: Task<Void, Never>?
    private var lastWorkingTreeChangeDate: Date?
    private var observers: [(id: UUID, callback: (GitRepositoryWatchingEvent) -> Void)] = []

    private static let workingTreeChangeThrottle: TimeInterval = 2

    public init() {}

    public func addObserver(
        _ callback: @escaping (GitRepositoryWatchingEvent) -> Void
    ) -> any GitRepositoryWatchingObserverHandle {
        let id = UUID()
        observers.append((id, callback))
        return Handle { [weak self] in
            self?.observers.removeAll { $0.id == id }
        }
    }

    public func startWatching(repositoryURL: URL) {
        let standardized = repositoryURL.standardizedFileURL
        guard watchingRepositoryURL?.standardizedFileURL != standardized else { return }
        if watchingRepositoryURL != nil {
            teardown(emitStopped: false)
        }

        do {
            let gitDirectory = try GitDirectoryResolver.resolveGitDirectory(for: standardized)
            watchedGitDirectory = gitDirectory.path
            lastSnapshot = GitDirectoryResolver.readSnapshot(gitDirectory: gitDirectory)
            watchingRepositoryURL = standardized
            gitWatcher = try GitDirectoryWatcher(url: gitDirectory) { [weak self] in
                self?.scheduleGitChangeCheck()
            }
            workingTreeWatcher = try WorkingTreeWatcher(url: standardized) { [weak self] in
                self?.scheduleWorkingTreeChange()
            }
            broadcast(.started(repositoryURL: standardized))
        } catch {
            teardown(emitStopped: false)
        }
    }

    public func stopWatching() {
        guard watchingRepositoryURL != nil else { return }
        teardown(emitStopped: true)
    }

    // Internal test visibility.
    var isWatcherActive: Bool { gitWatcher != nil && workingTreeWatcher != nil }
    var watchedGitDirectoryPath: String? { watchedGitDirectory }

    private func teardown(emitStopped: Bool) {
        gitDebounceTask?.cancel()
        gitDebounceTask = nil
        workingTreeDebounceTask?.cancel()
        workingTreeDebounceTask = nil
        gitWatcher?.stop()
        gitWatcher = nil
        workingTreeWatcher?.stop()
        workingTreeWatcher = nil
        watchedGitDirectory = nil
        lastSnapshot = nil
        lastWorkingTreeChangeDate = nil
        watchingRepositoryURL = nil
        if emitStopped { broadcast(.stopped) }
    }

    private func scheduleGitChangeCheck() {
        gitDebounceTask?.cancel()
        gitDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self?.checkGitDirectoryChange()
        }
    }

    private func checkGitDirectoryChange() {
        guard let watchedGitDirectory else { return }
        let current = GitDirectoryResolver.readSnapshot(
            gitDirectory: URL(fileURLWithPath: watchedGitDirectory, isDirectory: true)
        )
        let previous = lastSnapshot
        let headChanged = current.head != previous?.head
        let indexChanged = current.index != previous?.index
        let stashChanged = current.stash != previous?.stash
        let refsChanged = current.refs != previous?.refs
        guard headChanged || indexChanged || stashChanged || refsChanged else { return }
        lastSnapshot = current

        if headChanged {
            broadcast(.headChanged(previousHead: previous?.head, head: current.head))
        }
        if indexChanged { broadcast(.indexChanged) }
        if stashChanged { broadcast(.stashChanged) }
        if refsChanged { broadcast(.refsChanged) }
    }

    private func scheduleWorkingTreeChange() {
        workingTreeDebounceTask?.cancel()
        workingTreeDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self?.broadcastWorkingTreeChangeIfAllowed()
        }
    }

    private func broadcastWorkingTreeChangeIfAllowed() {
        let now = Date()
        if let lastWorkingTreeChangeDate,
           now.timeIntervalSince(lastWorkingTreeChangeDate) < Self.workingTreeChangeThrottle {
            return
        }
        lastWorkingTreeChangeDate = now
        broadcast(.workingTreeChanged)
    }

    private func broadcast(_ event: GitRepositoryWatchingEvent) {
        let current = observers
        for observer in current {
            observer.callback(event)
        }
    }

    private final class Handle: GitRepositoryWatchingObserverHandle {
        private let onCancel: () -> Void

        init(onCancel: @escaping () -> Void) {
            self.onCancel = onCancel
        }

        func cancel() { onCancel() }
    }
}
