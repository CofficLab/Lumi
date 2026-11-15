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
    private var gitSnapshotTask: Task<Void, Never>?
    private var workingTreeDebounceTask: Task<Void, Never>?
    private var workingTreeTrailingTask: Task<Void, Never>?
    private var lastWorkingTreeChangeDate: Date?
    /// 每次开始/停止监听自增，作为快照异步写回的身份令牌：
    /// 旧仓库的快照晚到时不得覆盖新仓库的状态（见 issue #1271 与仓库异步写回约定）。
    private var watchGeneration = 0
    /// 弱引用持有订阅令牌：外部释放令牌后，其 deinit 即视为自动注销，
    /// 下次广播时清理已失效的弱引用（与 `DefaultProjectProvider` 一致）。
    private var observers: [WeakObserver] = []

    private let workingTreeChangeThrottle: TimeInterval
    /// 快照读取器。默认走 `GitDirectoryResolver.readSnapshot`，在后台任务里调用；
    /// 测试可注入带延迟/线程记录的版本，验证 off-main 与身份校验。
    private let snapshotReader: @Sendable (URL) -> GitDirectorySnapshot

    public convenience init() {
        self.init(
            workingTreeChangeThrottle: 2,
            snapshotReader: { GitDirectoryResolver.readSnapshot(gitDirectory: $0) }
        )
    }

    /// 测试可注入较短的节流窗口，避免回归用例等待真实的 2 秒。
    convenience init(workingTreeChangeThrottle: TimeInterval) {
        self.init(
            workingTreeChangeThrottle: workingTreeChangeThrottle,
            snapshotReader: { GitDirectoryResolver.readSnapshot(gitDirectory: $0) }
        )
    }

    init(
        workingTreeChangeThrottle: TimeInterval,
        snapshotReader: @escaping @Sendable (URL) -> GitDirectorySnapshot
    ) {
        self.workingTreeChangeThrottle = workingTreeChangeThrottle
        self.snapshotReader = snapshotReader
    }

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
            watchingRepositoryURL = standardized
            watchGeneration += 1
            let generation = watchGeneration
            gitWatcher = try GitDirectoryWatcher(url: gitDirectory) { [weak self] in
                self?.scheduleGitChangeCheck()
            }
            workingTreeWatcher = try WorkingTreeWatcher(url: standardized) { [weak self] in
                self?.scheduleWorkingTreeChange()
            }
            broadcast(.started(repositoryURL: standardized))
            // 初始基线快照放到后台计算：大仓库打开/切换时不再在主线程读整个 index + refs（#1271）。
            computeSnapshot(gitDirectory: gitDirectory, generation: generation, isBaseline: true)
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
        watchGeneration += 1
        gitDebounceTask?.cancel()
        gitDebounceTask = nil
        gitSnapshotTask?.cancel()
        gitSnapshotTask = nil
        workingTreeDebounceTask?.cancel()
        workingTreeDebounceTask = nil
        workingTreeTrailingTask?.cancel()
        workingTreeTrailingTask = nil
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
        computeSnapshot(
            gitDirectory: URL(fileURLWithPath: watchedGitDirectory, isDirectory: true),
            generation: watchGeneration,
            isBaseline: false
        )
    }

    /// 在后台任务里读取快照，回到主线程时先校验身份再写回（#1271）。
    /// 整个 index 的逐字节哈希与 refs 枚举都不再占用主线程。
    private func computeSnapshot(gitDirectory: URL, generation: Int, isBaseline: Bool) {
        gitSnapshotTask?.cancel()
        let reader = snapshotReader
        gitSnapshotTask = Task { [weak self] in
            let snapshot = await Task.detached(priority: .utility) {
                reader(gitDirectory)
            }.value
            guard !Task.isCancelled else { return }
            guard let self, self.watchGeneration == generation else { return }
            if isBaseline {
                // 期间若已有变更检查写入更新的快照，不要用较旧的初始基线覆盖。
                if self.lastSnapshot == nil { self.lastSnapshot = snapshot }
            } else {
                self.applyChangeSnapshot(snapshot)
            }
        }
    }

    private func applyChangeSnapshot(_ current: GitDirectorySnapshot) {
        guard let previous = lastSnapshot else {
            // 基线尚未就绪（启动竞态）：把当前快照作为基线，不广播虚假变更。
            lastSnapshot = current
            return
        }
        // 同 commit 切换分支只改 HEAD 符号引用，hash 不变；两者任一变化都算 HEAD 变化（#213）。
        let headChanged = current.head != previous.head || current.headRef != previous.headRef
        let indexChanged = current.index != previous.index
        let stashChanged = current.stash != previous.stash
        let refsChanged = current.refs != previous.refs
        guard headChanged || indexChanged || stashChanged || refsChanged else { return }
        lastSnapshot = current

        if headChanged {
            broadcast(.headChanged(previousHead: previous.head, head: current.head))
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

    func broadcastWorkingTreeChangeIfAllowed() {
        let now = Date()
        if let lastWorkingTreeChangeDate,
           now.timeIntervalSince(lastWorkingTreeChangeDate) < workingTreeChangeThrottle {
            // 节流窗口内不立即广播，但安排一次尾随广播：窗口结束后补发最终状态。
            // 否则窗口内的最后一次变更被直接丢弃，Changes 面板长期停在旧状态（#357）。
            let remaining = workingTreeChangeThrottle - now.timeIntervalSince(lastWorkingTreeChangeDate)
            scheduleWorkingTreeTrailingBroadcast(after: remaining)
            return
        }
        workingTreeTrailingTask?.cancel()
        workingTreeTrailingTask = nil
        lastWorkingTreeChangeDate = now
        broadcast(.workingTreeChanged)
    }

    /// 窗口结束后补发一次最终状态；重复安排时取消上一个，把窗口内的多次变更合并成一次尾随广播。
    private func scheduleWorkingTreeTrailingBroadcast(after delay: TimeInterval) {
        workingTreeTrailingTask?.cancel()
        workingTreeTrailingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.broadcastWorkingTreeChangeIfAllowed()
        }
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
