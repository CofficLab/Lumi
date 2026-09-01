import Foundation
import ProviderProject

/// Converts ProjectProviding events into Preview ViewModel updates.
@MainActor
final class EditorPreviewProjectObserver {
    private var observer: (any ProjectProvidingObserverHandle)?

    init(
        project: any ProjectProviding,
        viewModel: EditorPreviewViewModel,
        onCurrentFileChanged: @escaping @MainActor (URL?) -> Void = { _ in }
    ) {
        observer = project.addObserver { [weak project, weak viewModel] event in
            switch event {
            case .currentFileChanged(let fileURL):
                viewModel?.updateCurrentFile(fileURL)
                onCurrentFileChanged(fileURL)
            case .currentProjectChanged:
                // Some providers change the project and current file in one
                // transaction, so read the provider's current value here.
                let currentFileURL = project?.currentFileURL
                viewModel?.updateCurrentFile(currentFileURL)
                onCurrentFileChanged(currentFileURL)
            case .projectsChanged, .openFilesChanged:
                break
            }
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }
}
