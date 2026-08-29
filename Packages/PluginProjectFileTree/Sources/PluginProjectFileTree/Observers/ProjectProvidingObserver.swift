import Foundation
import KitSuperLog
import os
import ProviderProject

/// 将 `ProjectProviding` 的当前项目变化同步到文件树 ViewModel。
@MainActor
final class ProjectProvidingObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.project-file-tree",
        category: "ProjectProvidingObserver"
    )
    nonisolated static let emoji = "🌲"
    nonisolated static let verbose = ProjectFileTreePlugin.verbose

    private weak var viewModel: ProjectFileTreeViewModel?
    private var observer: (any ProjectProvidingObserverHandle)?

    init(
        project: any ProjectProviding,
        viewModel: ProjectFileTreeViewModel,
        onProjectChange: ((ProjectInfo?) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        viewModel.updateCurrentProject(project.currentProject)
        observer = project.addObserver { [weak self] event in
            guard case let .currentProjectChanged(project) = event else { return }
            self?.viewModel?.updateCurrentProject(project)
            onProjectChange?(project)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 ProjectProviding 当前项目观察者")
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }
}
