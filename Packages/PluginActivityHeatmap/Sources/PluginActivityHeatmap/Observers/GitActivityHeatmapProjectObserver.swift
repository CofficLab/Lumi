import Foundation
import ProviderActivityHeatmap

/// Owns the external Provider subscription for the project settings section.
///
/// 在插件组装层创建，初始化时写入初值并订阅 Provider 变化；
/// 收到事件后**直接修改** `GitActivityHeatmapProjectViewModel`，不向外传回调。
@MainActor
final class GitActivityHeatmapProjectObserver {
    private let capability: GitActivityHeatmapProjectCapability
    private let viewModel: GitActivityHeatmapProjectViewModel
    private var handle: (any ActivityHeatmapObserverHandle)?

    init(capability: GitActivityHeatmapProjectCapability, viewModel: GitActivityHeatmapProjectViewModel) {
        self.capability = capability
        self.viewModel = viewModel
        viewModel.sync(snapshot: capability.snapshot, isLoading: capability.isLoading)
        handle = capability.addObserver { [weak self] _ in
            guard let self else { return }
            self.viewModel.sync(snapshot: self.capability.snapshot, isLoading: self.capability.isLoading)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
