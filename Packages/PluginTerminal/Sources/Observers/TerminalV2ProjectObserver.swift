import Combine
import ProviderProject
import SwiftUI

/// Observes the current project path for the terminal workspace.
@MainActor
final class TerminalV2ProjectObserver: ObservableObject {
    @Published private(set) var currentPath: String?
    private var handle: (any ProjectProvidingObserverHandle)?
    private var project: (any ProjectProviding)?

    init(project: (any ProjectProviding)?) {
        self.project = project
        bind(project: project)
    }

    func bind(project: (any ProjectProviding)?) {
        handle?.cancel()
        self.project = project
        currentPath = project?.currentProject?.path
        handle = project?.addObserver { [weak self] event in
            guard case .currentProjectChanged = event else { return }
            self?.currentPath = self?.project?.currentProject?.path
        }
    }

    func cancel() {
        bind(project: nil)
    }

}
