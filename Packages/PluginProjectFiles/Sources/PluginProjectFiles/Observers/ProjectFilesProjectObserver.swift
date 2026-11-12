import Foundation
import ProviderProject

/// Forwards project state changes to Project Files consumers.
@MainActor
final class ProjectFilesProjectObserver {
    private var handle: (any ProjectProvidingObserverHandle)?

    init(project: any ProjectProviding, onChange: @escaping () -> Void) {
        handle = project.addObserver { event in
            switch event {
            case .projectsChanged:
                break
            case .currentProjectChanged, .openFilesChanged, .currentFileChanged:
                onChange()
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
