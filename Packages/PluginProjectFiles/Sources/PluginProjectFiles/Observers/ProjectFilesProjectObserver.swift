import Foundation
import ProviderProject

/// Forwards project state changes to Project Files consumers.
@MainActor
final class ProjectFilesProjectObserver {
    private var handle: (any ProjectProvidingObserverHandle)?

    init(project: any ProjectProviding, onChange: @escaping () -> Void) {
        handle = project.addObserver { _ in
            onChange()
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
