import Foundation
import ProviderActivityHeatmap

/// Bridges the plugin-owned activity Provider to the project settings view.
/// The view never subscribes to Provider state directly; it only reads this
/// ViewModel and triggers intents. The Observer writes Provider changes into it.
@MainActor
final class GitActivityHeatmapProjectViewModel: ObservableObject {
    @Published private(set) var snapshot: ActivityHeatmapSnapshot?
    @Published private(set) var isLoading = false

    private let capability: GitActivityHeatmapProjectCapability
    private var projectPath: String

    init(projectPath: String, capability: GitActivityHeatmapProjectCapability) {
        self.projectPath = projectPath
        self.capability = capability
    }

    /// 用户/外部发起的刷新意图。
    func refresh() {
        capability.refresh(projectPath: projectPath)
        sync(snapshot: capability.snapshot, isLoading: capability.isLoading)
    }

    /// 项目路径变化（同一 Section 复用）时由 View 触发。
    func update(projectPath: String) {
        guard self.projectPath != projectPath else { return }
        self.projectPath = projectPath
        refresh()
    }

    /// Observer 写入：Provider 快照/加载状态变化。
    func sync(snapshot: ActivityHeatmapSnapshot?, isLoading: Bool) {
        let normalizedPath = URL(fileURLWithPath: projectPath).standardizedFileURL.path
        self.snapshot = snapshot?.repositoryPath == normalizedPath ? snapshot : nil
        self.isLoading = isLoading && self.snapshot == nil
    }
}
