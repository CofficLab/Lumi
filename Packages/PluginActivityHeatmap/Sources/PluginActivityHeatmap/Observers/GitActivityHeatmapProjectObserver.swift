import Foundation
import ProviderActivityHeatmap

/// Owns the external Provider subscription for the project settings section.
@MainActor
final class GitActivityHeatmapProjectObserver {
    private let provider: any ActivityHeatmapProviding
    private let viewModel: GitActivityHeatmapProjectViewModel
    private var handle: (any ActivityHeatmapObserverHandle)?

    init(provider: any ActivityHeatmapProviding, viewModel: GitActivityHeatmapProjectViewModel) {
        self.provider = provider
        self.viewModel = viewModel
        viewModel.sync(snapshot: provider.currentSnapshot, isLoading: provider.isLoading)
        handle = provider.addObserver { [weak self] _ in
            guard let self else { return }
            self.viewModel.sync(snapshot: provider.currentSnapshot, isLoading: provider.isLoading)
        }
    }

    func refresh(for projectPath: String) {
        provider.refresh(for: URL(fileURLWithPath: projectPath, isDirectory: true))
        viewModel.sync(snapshot: provider.currentSnapshot, isLoading: provider.isLoading)
    }

    func update(projectPath: String) {
        viewModel.update(
            projectPath: projectPath,
            snapshot: provider.currentSnapshot,
            isLoading: provider.isLoading
        )
        refresh(for: projectPath)
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
