import Foundation
import ProviderGitRepositoryWatch

/// 记录订阅状态的仓库监听替身。
///
/// 用于验证「外部改动分支后胶囊是否刷新」这类行为：测试只需调用
/// ``send(_:)`` 广播一个事件，即可模拟 `.git` 目录变化被监听到。
@MainActor
final class StubGitRepositoryWatching: GitRepositoryWatching {
    private(set) var watchingRepositoryURL: URL?
    private var observers: [(id: UUID, callback: (GitRepositoryWatchingEvent) -> Void)] = []

    init() {}

    func addObserver(
        _ callback: @escaping (GitRepositoryWatchingEvent) -> Void
    ) -> any GitRepositoryWatchingObserverHandle {
        let id = UUID()
        observers.append((id: id, callback: callback))
        return Handle { [weak self] in
            self?.observers.removeAll { $0.id == id }
        }
    }

    func startWatching(repositoryURL: URL) {
        watchingRepositoryURL = repositoryURL
    }

    func stopWatching() {
        watchingRepositoryURL = nil
    }

    /// 广播一个事件给所有订阅方。
    func send(_ event: GitRepositoryWatchingEvent) {
        for observer in observers {
            observer.callback(event)
        }
    }

    /// 当前订阅方数量。
    var observerCount: Int { observers.count }

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
