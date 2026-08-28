import Foundation
import KernelCore

/// Projects 运行时（KernelCore 版本）：在 `onBoot` 时装配 Store / ViewModel /
/// SyncCoordinator,并提供给 Agent 工具与视图访问。
///
/// 复刻自旧版 `RuntimeBridge`(KernelLumi),差异:
/// - 增加 `configure` / `reset` 生命周期管理,与 `MindMapDesignerRuntime` 保持一致;
/// - 不持有 `kernel` 强引用——同步协调器通过 `ProjectsSyncCoordinator.kernel` 弱引用绑定。
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
