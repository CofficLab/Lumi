import Foundation
import ProviderActivityHeatmap

/// Bridges the plugin-owned activity Provider to the project settings view.
/// The view never subscribes to Provider state directly.
@MainActor
final class GitActivityHeatmapProjectViewModel: ObservableObject {
    @Published private(set) var snapshot: ActivityHeatmapSnapshot?
    @Published private(set) var isLoading = false

    private var projectPath: String

    init(projectPath: String) {
        self.projectPath = projectPath
    }

    func update(projectPath: String, snapshot: ActivityHeatmapSnapshot?, isLoading: Bool) {
        guard self.projectPath != projectPath else { return }
        self.projectPath = projectPath
        sync(snapshot: snapshot, isLoading: isLoading)
    }

    func sync(snapshot: ActivityHeatmapSnapshot?, isLoading: Bool) {
        let normalizedPath = URL(fileURLWithPath: projectPath).standardizedFileURL.path
        self.snapshot = snapshot?.repositoryPath == normalizedPath ? snapshot : nil
        self.isLoading = isLoading && self.snapshot == nil
    }
}
