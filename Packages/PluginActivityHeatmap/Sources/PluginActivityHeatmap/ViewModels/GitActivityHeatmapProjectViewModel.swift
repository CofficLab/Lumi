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
        // 其他仓库的刷新（当前项目的 refsChanged 等会切换共享 Provider 的
        // 快照）与本 Section 无关，必须整体忽略：既不改快照也不改加载状态，
        // 否则设置页里正在展示的项目会被清成「无提交活动」（#371）。
        if let snapshot, snapshot.repositoryPath != normalizedPath { return }
        self.snapshot = snapshot
        self.isLoading = isLoading && snapshot == nil
    }
}
