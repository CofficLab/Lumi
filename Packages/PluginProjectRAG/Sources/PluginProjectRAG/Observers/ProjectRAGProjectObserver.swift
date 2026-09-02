import Foundation
import ProviderProject

/// Forwards project changes to the public Project RAG event stream.
@MainActor
final class ProjectRAGProjectObserver {
    private var handle: (any ProjectProvidingObserverHandle)?

    init(project: any ProjectProviding, onCurrentProjectChange: @escaping () -> Void) {
        handle = project.addObserver { event in
            guard case .currentProjectChanged = event else { return }
            onCurrentProjectChange()
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
