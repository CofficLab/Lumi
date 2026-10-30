import Foundation
import LumiLoggingKit
import os
import ProviderGitRepositoryWatch
import ProviderProject

/// 监听「当前项目变化」与「仓库 HEAD / refs 变化」，把仓库状态同步到分支胶囊 ViewModel。
///
/// - 项目切换后 ViewModel 会重新判定该路径是否为 Git 仓库；
///   非 Git 项目时分支胶囊自动消失。
/// - 仓库监听用于捕获**外部**的分支变动（终端 `git checkout`、IDE 切分支、
///   Agent 调用 git 工具等）：这些操作只改 `.git/HEAD` 与 `refs/heads`，
///   不会经过本插件，因此必须靠 watch 事件才能感知。
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
    private var repositoryObserver: (any GitRepositoryWatchingObserverHandle)?

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

    /// 订阅仓库监听事件，使胶囊能跟随外部的分支切换刷新。
    ///
    /// 未启用仓库监听时不做任何事——胶囊仍可正常显示与切换分支，只是不会
    /// 自动跟随外部变动。
    func observeRepository(
        _ capability: any GitBranchCapability
    ) {
        guard repositoryObserver == nil else { return }
        repositoryObserver = capability.addRepositoryObserver { [weak self] event in
            switch event {
            case .started, .stopped, .headChanged, .refsChanged:
                // HEAD 变化 = 切分支 / 提交；refs 变化 = 新建或删除分支。
                // 两者都要重读，否则胶囊会停在旧分支名。
                self?.viewModel?.refresh()
            case .indexChanged, .stashChanged, .workingTreeChanged:
                // 与分支无关，不触发刷新。
                break
            }
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
        repositoryObserver?.cancel()
        repositoryObserver = nil
    }
}
