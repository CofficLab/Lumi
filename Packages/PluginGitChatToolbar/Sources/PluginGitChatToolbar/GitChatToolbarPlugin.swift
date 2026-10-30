import Foundation
import KernelCore
import LumiLoggingKit
import os
import ProviderChatSection
import ProviderGit
import ProviderGitRepositoryWatch
import ProviderProject
import SwiftUI

/// Chat Toolbar 上的 Git 入口：一个胶囊按钮 + 弹层，展示 commit 列表与工作区变更。
///
/// 遵循项目规范：
/// - 插件之间不得互相依赖：只依赖 ProviderGit / ProviderProject / ProviderGitRepositoryWatch / ProviderChatSection 等契约包；
/// - Capabilities 规范：ViewModel 只依赖 ``GitChatCapability`` / ``GitChatProjectCapability`` 窄协议，由 Adapter 包装；
/// - View/ViewModel 不直接持有任何 `any *Providing`：外部事件由 ``GitChatObserver`` 翻译；
/// - UI 项 order 派生自插件 `order`（本项目 `order = 52`）。
@MainActor
public final class GitChatToolbarPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.git-chat-toolbar",
        category: "GitChatToolbar"
    )

    public let id = "com.coffic.lumi.plugin.git-chat-toolbar"
    public let order = 52
    public let dependencies = [
        "com.coffic.lumi.plugin.git",
        "com.coffic.lumi.plugin.git-repository-watch",
        "com.coffic.lumi.plugin.projects",
    ]
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.git-chat-toolbar",
        name: pluginLocalization.string("Git Changes"),
        description: pluginLocalization.string("Quick commit list and working tree changes in the chat toolbar."),
        category: .project,
        stage: .preview,
        policy: .enabledByDefault
    )

    private var capability: GitChatCapabilityAdapter?
    private var projectCapability: GitChatProjectCapabilityAdapter?
    private var viewModel: GitChatToolbarViewModel?
    private var observer: GitChatObserver?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)ChatSectionProviding is not registered; skip Git chat toolbar")
            return
        }
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            Self.logger.error("\(Self.t)ProjectProviding is not registered; skip Git chat toolbar")
            return
        }
        let git = kernel.resolveProvider((any GitRepositoryReading).self)
        let watch = kernel.resolveProvider((any GitRepositoryWatching).self)

        let capability = GitChatCapabilityAdapter(provider: git)
        self.capability = capability

        let projectCapability = GitChatProjectCapabilityAdapter(project: project)
        self.projectCapability = projectCapability

        let viewModel = GitChatToolbarViewModel(
            capability: capability,
            projectCapability: projectCapability
        )
        self.viewModel = viewModel

        self.observer = GitChatObserver(
            project: project,
            watch: watch,
            viewModel: viewModel
        )

        // 注册 ChatToolbar bar item；非 Git 项目时 ViewModel 渲染 EmptyView。
        let itemID = "\(id).toolbar"
        chat.removeBarItem(id: itemID)
        chat.addBarItems([
            ChatSectionBarItem(
                id: itemID,
                order: order,
                placement: .toolbarTrailing
            ) { [weak viewModel] in
                if let viewModel {
                    GitChatToolbarButtonContainer(viewModel: viewModel)
                } else {
                    EmptyView()
                }
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar")
        observer?.cancel()
        observer = nil
        viewModel = nil
        projectCapability = nil
        capability = nil
    }
}

/// 包装 ``GitChatToolbarButton``：非 Git 仓库时渲染 EmptyView。
///
/// 用独立容器把「非 Git 项目时不占位」的分支收敛在视图层，避免在
/// ``GitChatToolbarButton`` 内判断 ViewModel 状态导致的布局抖动。
private struct GitChatToolbarButtonContainer: View {
    @ObservedObject var viewModel: GitChatToolbarViewModel

    var body: some View {
        if viewModel.isGitRepository {
            GitChatToolbarButton(viewModel: viewModel)
        } else {
            EmptyView()
        }
    }
}
