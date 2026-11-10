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
    /// 弱引用持有订阅令牌：外部释放令牌后，其 deinit 即视为自动注销，
    /// 下次广播时清理已失效的弱引用（与 `DefaultProjectProvider` 一致）。
    private var observers: [WeakObserver] = []

    private static let workingTreeChangeThrottle: TimeInterval = 2

    public init() {}

    public func addObserver(
        _ callback: @escaping (GitRepositoryWatchingEvent) -> Void
    ) -> any GitRepositoryWatchingObserverHandle {
        let handle = Handle(owner: self, callback: callback)
        observers.append(WeakObserver(handle))
        return handle
    }

    private func remove(_ handle: Handle) {
        observers.removeAll { $0.handle === handle }
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
        observers.removeAll { $0.handle == nil }
        let current = observers
        for observer in current {
            observer.handle?.invoke(event)
        }
    }

    private final class Handle: GitRepositoryWatchingObserverHandle {
        private weak var owner: GitRepositoryWatchProvider?
        private let callback: (GitRepositoryWatchingEvent) -> Void
        private var isCancelled = false

        init(
            owner: GitRepositoryWatchProvider,
            callback: @escaping (GitRepositoryWatchingEvent) -> Void
        ) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            owner?.remove(self)
        }

        fileprivate func invoke(_ event: GitRepositoryWatchingEvent) {
            guard !isCancelled else { return }
            callback(event)
        }
    }

    private final class WeakObserver {
        weak var handle: Handle?

        init(_ handle: Handle) {
            self.handle = handle
        }
    }
}
