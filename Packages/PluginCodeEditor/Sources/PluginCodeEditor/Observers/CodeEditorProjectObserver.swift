import Foundation
import ProviderProject

/// Forwards current-file changes from the project provider to the editor model.
@MainActor
final class CodeEditorProjectObserver {
    private var handle: (any ProjectProvidingObserverHandle)?

    init(project: any ProjectProviding, onCurrentFileChange: @escaping (URL?) -> Void) {
        handle = project.addObserver { [weak project] event in
            guard case .currentFileChanged = event else { return }
            onCurrentFileChange(project?.currentFileURL)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
