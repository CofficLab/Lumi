import Foundation
import LumiLoggingKit
import os
import ProviderProject

/// Chat Toolbar ASC 面板的外部事件观察器。
///
/// 订阅 `ProjectProviding` 的「当前项目变化」事件，把项目路径翻译成
/// ViewModel 的刷新请求。观察器由插件入口创建并持有，`cancel()` 在
/// `onShutdown` 调用。
@MainActor
final class ASCChatToolbarObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.app-store-connect",
        category: "ASCChatToolbarObserver"
    )
    nonisolated static let emoji = "🏪"

    private weak var viewModel: ASCChatToolbarViewModel?
    private var projectHandle: (any ProjectProvidingObserverHandle)?

    init(project: any ProjectProviding, viewModel: ASCChatToolbarViewModel) {
        self.viewModel = viewModel
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
    }

    func cancel() {
        projectHandle?.cancel()
        projectHandle = nil
    }
}
