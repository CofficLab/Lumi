import Foundation
import ProviderProject

/// Forwards current-project changes to the mind-map runtime.
@MainActor
final class MindMapProjectObserver {
    private var handle: (any ProjectProvidingObserverHandle)?

    init(project: any ProjectProviding, onChange: @escaping (String?) -> Void) {
        handle = project.addObserver { [weak project] event in
            guard case .currentProjectChanged = event else { return }
            onChange(project?.currentProject?.path)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
