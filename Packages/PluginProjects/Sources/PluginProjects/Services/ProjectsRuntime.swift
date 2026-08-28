import Foundation
import KernelCore

/// Projects 运行时：在 `onBoot` 时装配 ViewModel / observer,
/// 并提供给 Agent 工具与视图访问。
@MainActor
public enum ProjectsRuntime {
    /// 当前 ViewModel（供工具与视图读取;未装配时为 nil）。
    static private(set) var viewModel: ProjectsViewModel?

    /// 当前项目状态观察者，保持其生命周期与插件一致。
    static private(set) var projectObserver: ProjectProvidingObserver?

    /// 装配运行时：注入 ViewModel 与 ProjectProviding observer。
    static func configure(
        viewModel: ProjectsViewModel,
        projectObserver: ProjectProvidingObserver
    ) {
        self.viewModel = viewModel
        self.projectObserver = projectObserver
    }

    /// 重置运行时（插件 shutdown 时调用）。
    static func reset() {
        projectObserver?.cancel()
        projectObserver = nil
        viewModel = nil
    }
}
