import Foundation

/// 仓库监听事件。
@MainActor
public enum GitRepositoryWatchingEvent: Equatable, Sendable {
    case started(repositoryURL: URL)
    case stopped
    case headChanged(previousHead: String?, head: String?)
    case indexChanged
    case stashChanged
    case refsChanged
    case workingTreeChanged
}

/// Git 仓库监听订阅句柄。
///
/// 句柄的生命周期即订阅生命周期：持有返回值即可持续接收事件；释放句柄等同于
/// 注销（实现需在下次广播时清理失效注册），也无需再调用 `cancel()`。
@MainActor
public protocol GitRepositoryWatchingObserverHandle: AnyObject {
    /// 立即停止接收事件；重复调用无副作用。
    func cancel()
}

/// 可复用的 Git 仓库监听 Provider。
///
/// Provider 只描述监听目标、事件和订阅生命周期，不绑定 FSEvents。真实实现
/// 可以使用 FSEventStream、轮询或宿主自己的文件系统事件源。
@MainActor
public protocol GitRepositoryWatching: AnyObject {
    var watchingRepositoryURL: URL? { get }

    @discardableResult
    func addObserver(
        _ callback: @escaping (GitRepositoryWatchingEvent) -> Void
    ) -> any GitRepositoryWatchingObserverHandle

    func startWatching(repositoryURL: URL)
    func stopWatching()
}

/// 测试、预览和没有真实文件监听时使用的内存实现。
@MainActor
public final class DefaultGitRepositoryWatching: GitRepositoryWatching {
    public private(set) var watchingRepositoryURL: URL?
    /// 弱引用持有订阅令牌：外部释放令牌后，其 deinit 即视为自动注销，
    /// 下次广播时清理已失效的弱引用（与 `DefaultProjectProvider` 一致）。
    private var observers: [WeakObserver] = []

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
        watchingRepositoryURL = standardized
        broadcast(.started(repositoryURL: standardized))
    }

    public func stopWatching() {
        guard watchingRepositoryURL != nil else { return }
        watchingRepositoryURL = nil
        broadcast(.stopped)
    }

    /// 供真实实现、测试和宿主主动操作完成后广播语义事件。
    public func broadcast(_ event: GitRepositoryWatchingEvent) {
        observers.removeAll { $0.handle == nil }
        let current = observers
        for observer in current {
            observer.handle?.invoke(event)
        }
    }

    private final class Handle: GitRepositoryWatchingObserverHandle {
        private weak var owner: DefaultGitRepositoryWatching?
        private let callback: (GitRepositoryWatchingEvent) -> Void
        private var isCancelled = false

        init(
            owner: DefaultGitRepositoryWatching,
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
