import Foundation
import KitSuperLog
import os
import ProviderProject

/// 将 `ProjectProviding` 的项目列表和当前项目变化同步到 Projects ViewModel。
@MainActor
final class ProjectProvidingObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.projects",
        category: "ProjectProvidingObserver"
    )
    nonisolated static let emoji = "📁"
    nonisolated static let verbose = false

    private weak var viewModel: ProjectsViewModel?
    private var observer: (any ProjectProvidingObserverHandle)?

    init(project: any ProjectProviding, viewModel: ProjectsViewModel) {
        self.viewModel = viewModel
        viewModel.syncFromProvider(persist: false)
        observer = project.addObserver { [weak self] event in
            switch event {
            case .projectsChanged, .currentProjectChanged:
                self?.viewModel?.syncFromProvider()
            case .openFilesChanged, .currentFileChanged:
                break
            }
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 ProjectProviding 项目状态观察者")
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }
}
