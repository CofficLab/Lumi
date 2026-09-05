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
@MainActor
public protocol GitRepositoryWatchingObserverHandle: AnyObject {
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
    private var observers: [(id: UUID, callback: (GitRepositoryWatchingEvent) -> Void)] = []

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

        func cancel() {
            onCancel()
        }
    }
}
