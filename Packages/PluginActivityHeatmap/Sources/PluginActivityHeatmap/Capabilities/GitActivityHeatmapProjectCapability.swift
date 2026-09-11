import Foundation
import ProviderActivityHeatmap

/// 收敛项目提交活动的 Provider 最小操作，供 ViewModel/Observer 使用。
@MainActor
final class GitActivityHeatmapProjectCapability {
    private let provider: any ActivityHeatmapProviding

    init(provider: any ActivityHeatmapProviding) {
        self.provider = provider
    }

    var snapshot: ActivityHeatmapSnapshot? { provider.currentSnapshot }
    var isLoading: Bool { provider.isLoading }

    func addObserver(_ handler: @escaping (ActivityHeatmapEvent) -> Void) -> (any ActivityHeatmapObserverHandle)? {
        provider.addObserver(handler)
    }

    func refresh(projectPath: String) {
        provider.refresh(for: URL(fileURLWithPath: projectPath, isDirectory: true))
    }
}
