import Combine
import KernelCore
import LumiLoggingKit
import LumiUI
import os
import ProviderGit
import ProviderProject
import ProviderToolbar
import SwiftUI

/// 标题栏 Git 分支胶囊插件。
///
/// - `onBoot` 中解析 `GitBranchManaging` 契约（由 `PluginGit` 发布），
///   装配 ViewModel 与项目观察者；
/// - 工具栏贡献按「当前项目是否为 Git 仓库」动态增删：非 Git 项目时
///   标题栏不出现任何分支相关控件；
/// - 贡献使用 `placement: .center` 且 `order` 大于 `PluginProjects` 的 0，
///   因此落在项目胶囊右侧。
@MainActor
public final class GitToolbarPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.git-toolbar",
        category: "GitToolbar"
    )

    public nonisolated static let emoji = "🌿"
    public let id = "com.coffic.lumi.plugin.git-toolbar"
    public let order = 12
    public let dependencies = [
        "com.coffic.lumi.plugin.git",
        "com.coffic.lumi.plugin.projects",
    ]
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.git-toolbar",
        name: "Git Branch",
        description: "Switch and create Git branches from the title bar.",
        category: .project,
        stage: .stable,
        policy: .alwaysOn
    )

    private var viewModel: GitBranchToolbarViewModel?
    private var observer: GitBranchProjectObserver?
    private var cancellables: Set<AnyCancellable> = []

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            Self.logger.error("\(Self.t)ProjectProviding is not registered; skip Git branch toolbar")
            return
        }
        guard let git = kernel.resolveProvider((any GitBranchManaging).self) else {
            Self.logger.error("\(Self.t)GitBranchManaging is not registered; skip Git branch toolbar")
            return
        }
        guard let toolbar = kernel.resolveProvider((any ToolbarProviding).self) else {
            Self.logger.error("\(Self.t)ToolbarProviding is not registered; skip Git branch toolbar")
            return
        }

        let capability = GitBranchCapabilityAdapter(provider: git)
        let viewModel = GitBranchToolbarViewModel(capability: capability)
        self.viewModel = viewModel
        self.observer = GitBranchProjectObserver(project: project, viewModel: viewModel)

        // 工具栏 center 段按 order 升序排列；Projects 使用 order 0，
        // 这里用插件自身 order，保证分支胶囊落在项目胶囊右侧。
        let itemID = "\(id).branch"
        viewModel.$isGitRepository
            .removeDuplicates()
            .sink { [weak toolbar] isRepository in
                guard let toolbar else { return }
                if isRepository {
                    toolbar.addToolbarItems([
                        ToolbarItem(
                            id: itemID,
                            title: pluginLocalization.string("Branch"),
                            placement: .center,
                            category: .project,
                            order: self.order
                        ) {
                            GitBranchToolbarButton(viewModel: viewModel)
                        },
                    ])
                } else {
                    toolbar.removeToolbarItems(ids: [itemID])
                }
            }
            .store(in: &cancellables)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        cancellables.removeAll()
        kernel.resolveProvider((any ToolbarProviding).self)?
            .removeToolbarItems(ids: ["\(id).branch"])
        observer?.cancel()
        observer = nil
        viewModel = nil
    }
}
