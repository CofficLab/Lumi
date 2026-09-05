import KernelCore
import KitSuperLog
import os
import GitPlugin
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderGitRepositoryWatch
import ProviderProject
import ProviderRailView
import ProviderRootView
import ProviderToolbar
import SwiftUI

/// Git 工作区入口。
///
/// GitSourceControlSuperPlugin 提供 Git 数据能力，本插件只负责把它呈现为
/// 一个可从 ActivityBar 打开的工作区面板。这样编辑器/Agent 的 Git 能力与
/// 桌面工作区 UI 保持独立，任一方都可以单独启停。
@MainActor
public final class GitWorkspacePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.git-workspace",
        category: "GitWorkspace"
    )

    public nonisolated static let emoji = "🌿"
    public let id = "com.coffic.lumi.plugin.git-workspace"
    public let order = 12
    public let dependencies = [
        "com.coffic.lumi.plugin.git",
        "com.coffic.lumi.plugin.git-repository-watch",
    ]
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.git-workspace",
        name: "Git Workspace",
        description: "View the current project's commit history and working tree status.",
        category: .project,
        stage: .stable,
        policy: .enabledByDefault
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            Self.logger.error("\(Self.t)ProjectProviding is not registered; skip Git workspace")
            return
        }

        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let root = kernel.resolveProvider((any RootViewProviding).self)
        let rail = kernel.resolveProvider((any RailViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let gitWatch = kernel.resolveProvider((any GitRepositoryWatching).self)
        let entryID = "\(id).entry"
        let view = AnyView(GitWorkspaceView(project: project, gitWatch: gitWatch))

        activityBar?.addItems([
            ActivityBarItem(
                id: entryID,
                title: metadata.name,
                systemImage: "point.3.connected.trianglepath.dotted",
                order: order,
                ownerPluginID: id
            ) { state in
                if state == .activated {
                    toolbar?.setVisibleCategories([.global, .project])
                    rail?.setVisibleCategories([.project])
                    root?.setRailView(nil)
                    root?.setContentHeaderViewHidden(true)
                    chat?.setVisible(false)
                    content?.setContentView(view)
                } else {
                    toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                    rail?.setVisibleCategories(Set(RailViewCategory.allCases))
                    root?.setRailView(rail?.makeRailView())
                    root?.setRailViewVisible(rail?.hasVisibleTabs ?? false)
                    root?.setContentHeaderViewHidden(false)
                    chat?.setVisible(true)
                }
            },
        ])

        // 供精简宿主（没有 ActivityBar 的专用 App）直接显示面板。
        if activityBar == nil {
            content?.setContentView(view)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        activityBar?.removeItems(ids: ["\(id).entry"])

        guard wasActive else { return }
        kernel.resolveProvider((any ToolbarProviding).self)?
            .setVisibleCategories(Set(ToolbarItemCategory.allCases))
        kernel.resolveProvider((any RailViewProviding).self)?
            .setVisibleCategories(Set(RailViewCategory.allCases))
        if let rail = kernel.resolveProvider((any RailViewProviding).self),
           let root = kernel.resolveProvider((any RootViewProviding).self) {
            root.setRailView(rail.makeRailView())
            root.setRailViewVisible(rail.hasVisibleTabs)
        }
        kernel.resolveProvider((any RootViewProviding).self)?
            .setContentHeaderViewHidden(false)
        kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(true)
        kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
    }
}
