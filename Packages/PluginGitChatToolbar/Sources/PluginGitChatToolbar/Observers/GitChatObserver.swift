import Foundation
import LumiLoggingKit
import os
import ProviderGitRepositoryWatch
import ProviderProject

/// Chat Toolbar 的外部事件观察器。
///
/// 订阅 ``ProjectProviding``（项目切换 → 整表重载）与 ``GitRepositoryWatching``
/// （`.headChanged`/`.refsChanged` → 重载 commits；`.indexChanged`/
/// `.workingTreeChanged` → 仅重载 changes），并把事件翻译成 ViewModel 的
/// 刷新请求。
///
/// 观察器由插件入口创建并持有，`cancel()` 在 `onShutdown` 调用，保证订阅
/// 句柄的生命周期与插件绑定。
@MainActor
final class GitChatObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.git-chat-toolbar",
        category: "GitChatObserver"
    )
    nonisolated static let emoji = "🌿"

    private weak var viewModel: GitChatToolbarViewModel?
    private var projectHandle: (any ProjectProvidingObserverHandle)?
    private var watchHandle: (any GitRepositoryWatchingObserverHandle)?

    init(
        project: any ProjectProviding,
        watch: (any GitRepositoryWatching)?,
        viewModel: GitChatToolbarViewModel
    ) {
        self.viewModel = viewModel
        // 用当前项目路径初始化 ViewModel（如果打开的是 Git 仓库）。
        viewModel.updateProjectPath(project.currentProject?.path)

        projectHandle = project.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .currentProjectChanged:
                self.viewModel?.updateProjectPath(project.currentProject?.path)
            case .projectsChanged, .openFilesChanged, .currentFileChanged:
                break
            }
        }

        watchHandle = watch?.addObserver { [weak self] event in
            switch event {
            case .started:
                self?.viewModel?.reloadAll()
            case .stopped:
                self?.viewModel?.resetForMissingWatch()
            case .headChanged, .refsChanged, .indexChanged, .workingTreeChanged, .stashChanged:
                // 全部事件都触发整表重载；ViewModel 内部节流避免频繁刷新。
                self?.viewModel?.reloadAll()
            }
        }
    }

    func cancel() {
        projectHandle?.cancel()
        projectHandle = nil
        watchHandle?.cancel()
        watchHandle = nil
    }
}
