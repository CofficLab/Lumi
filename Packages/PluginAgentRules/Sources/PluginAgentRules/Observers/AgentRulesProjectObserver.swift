import Foundation
import ProviderProject

/// Observes the project catalog used by the Agent Rules settings page.
///
/// 在插件组装层创建，初始化时写入初值并订阅 `ProjectProviding` 变化；
/// 收到事件后**直接修改** `AgentRulesViewModel`，不向外传回调。
@MainActor
final class AgentRulesProjectObserver {
    private let viewModel: AgentRulesViewModel
    private var handle: (any ProjectProvidingObserverHandle)?

    init(
        projectProvider: (any ProjectProviding)?,
        viewModel: AgentRulesViewModel
    ) {
        self.viewModel = viewModel
        viewModel.updateProjects(projectProvider?.projects ?? [])
        handle = projectProvider?.addObserver { [weak self] event in
            guard let self, case .projectsChanged(let projects) = event else { return }
            self.viewModel.updateProjects(projects)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
