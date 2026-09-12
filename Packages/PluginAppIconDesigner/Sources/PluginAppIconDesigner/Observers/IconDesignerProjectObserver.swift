import Foundation
import ProviderProject

/// Forwards current-project changes to the icon designer view model.
///
/// 在插件组装层创建，收到事件后**直接修改** `AppIconDesignerViewModel`，
/// 不向外传回调。
@MainActor
final class IconDesignerProjectObserver {
    private let viewModel: AppIconDesignerViewModel
    private var handle: (any ProjectProvidingObserverHandle)?

    init(
        project: any ProjectProviding,
        viewModel: AppIconDesignerViewModel
    ) {
        self.viewModel = viewModel
        viewModel.handleCurrentProjectChange(path: project.currentProject?.path)
        handle = project.addObserver { [weak project, weak self] event in
            guard let self, case .currentProjectChanged = event else { return }
            self.viewModel.handleCurrentProjectChange(path: project?.currentProject?.path)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
