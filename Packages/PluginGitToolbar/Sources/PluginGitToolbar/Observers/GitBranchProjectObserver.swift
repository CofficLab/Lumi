import Foundation
import LumiLoggingKit
import os
import ProviderProject

/// 监听「当前项目变化」，把项目路径同步到分支胶囊 ViewModel。
///
/// 项目切换后 ViewModel 会重新判定该路径是否为 Git 仓库；
/// 非 Git 项目时分支胶囊自动消失。
@MainActor
final class GitBranchProjectObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.git-toolbar",
        category: "GitBranchProjectObserver"
    )
    nonisolated static let emoji = "🌿"
    nonisolated static let verbose = false

    private weak var viewModel: GitBranchToolbarViewModel?
    private var observer: (any ProjectProvidingObserverHandle)?

    init(project: any ProjectProviding, viewModel: GitBranchToolbarViewModel) {
        self.viewModel = viewModel
        viewModel.updateProject(path: project.currentProject?.path)
        observer = project.addObserver { [weak self] event in
            switch event {
            case .currentProjectChanged:
                self?.viewModel?.updateProject(path: project.currentProject?.path)
            case .projectsChanged, .openFilesChanged, .currentFileChanged:
                break
            }
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }
}
