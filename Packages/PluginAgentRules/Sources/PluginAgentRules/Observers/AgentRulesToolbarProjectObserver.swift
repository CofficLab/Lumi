import Foundation
import ProviderProject

/// Forwards current-project changes to the Chat toolbar ViewModel.
@MainActor
final class AgentRulesToolbarProjectObserver {
    private let viewModel: AgentRulesToolbarViewModel
    private var handle: (any ProjectProvidingObserverHandle)?

    init(projectProvider: (any ProjectProviding)?, viewModel: AgentRulesToolbarViewModel) {
        self.viewModel = viewModel
        viewModel.updateProject(path: projectProvider?.currentProject?.path)
        handle = projectProvider?.addObserver { [weak self] event in
            guard let self, case let .currentProjectChanged(project, _) = event else { return }
            self.viewModel.updateProject(path: project?.path)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
