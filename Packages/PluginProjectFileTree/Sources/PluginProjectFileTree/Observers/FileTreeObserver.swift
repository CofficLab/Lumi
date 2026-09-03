import Foundation
import KitFileSystem

/// 文件树唯一的 FileTreeWatcher 持有者。
///
/// 观察器由插件入口创建并销毁，RefreshCoordinator 只负责把变化转换成
/// ViewModel 可消费的刷新状态，不再自行注册外部文件系统监听。
final class FileTreeObserver {
    private final class WeakCoordinator: @unchecked Sendable {
        weak var value: RefreshCoordinator?
    }

    private let watcher: FileTreeWatcher

    init(coordinator: RefreshCoordinator) {
        let box = WeakCoordinator()
        watcher = FileTreeWatcher { changedURL in
            box.value?.handleDirectoryChanged(url: changedURL)
        }
        box.value = coordinator
        coordinator.attach(observer: self)
    }

    func updateWatchedDirectories(_ directories: Set<URL>) {
        watcher.updateWatchedDirectories(directories)
    }

    func stopWatching() {
        watcher.stopAll()
    }
}
