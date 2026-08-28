import Foundation
import KernelCore

/// Projects 运行时：在 `onBoot` 时装配 Store / ViewModel /
/// SyncCoordinator,并提供给 Agent 工具与视图访问。
@MainActor
public enum ProjectsRuntime {
    /// 当前 ViewModel（供工具与视图读取;未装配时为 nil）。
    static private(set) var viewModel: ProjectsViewModel?

    /// 当前同步协调器（供外部触发初始同步）。
    static private(set) var syncCoordinator: ProjectsSyncCoordinator?

    /// 装配运行时:注入 ViewModel 与同步协调器。
    static func configure(
        viewModel: ProjectsViewModel,
        syncCoordinator: ProjectsSyncCoordinator
    ) {
        self.viewModel = viewModel
        self.syncCoordinator = syncCoordinator
    }

    /// 重置运行时（插件 shutdown 时调用）。
    static func reset() {
        syncCoordinator = nil
        viewModel = nil
    }
}
