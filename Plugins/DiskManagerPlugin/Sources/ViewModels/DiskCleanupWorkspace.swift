import Foundation
import Combine

/// DiskManager 各清理类型的共享 ViewModel 容器。
///
/// 让 5 个清理类型的 ViewModel 各自保持独立生命周期，这样：
/// - 切换清理类型时，对应的 ViewModel 不会被销毁，扫描/结果不丢失；
/// - 多个类型可以并行扫描（互不抢资源）；
/// - SwiftUI 重建主视图时（`makeView` 多次调用）也能复用同一份 ViewModel。
///
/// 由 ``DiskManagerPlugin`` 持有唯一实例，并透传给 ``DiskManagerView``。
@MainActor
final class DiskCleanupWorkspace: ObservableObject {
    let largeFiles: LargeFilesViewModel
    let directoryTree: DirectoryTreeViewModel
    let cacheCleaner: CacheCleanerViewModel
    let xcodeCleaner: XcodeCleanerViewModel
    let projectCleaner: ProjectCleanerViewModel

    init() {
        self.largeFiles = LargeFilesViewModel()
        self.directoryTree = DirectoryTreeViewModel()
        self.cacheCleaner = CacheCleanerViewModel()
        self.xcodeCleaner = XcodeCleanerViewModel()
        self.projectCleaner = ProjectCleanerViewModel()
    }
}