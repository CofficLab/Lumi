import KernelLumi
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// Git 集成插件
@MainActor
public final class GitPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "🟢"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.git"
    )

    public let id = "com.coffic.lumi.plugin.git"

    /// 本插件 Git 历史面板的稳定标识（注册为 `PanelRailTabItem.id`）。
    public nonisolated static let historyTabID = "com.coffic.lumi.plugin.git.history"

    /// 本插件 Git 工具面板的稳定标识（注册为 `PanelRailTabItem.id`）。
    public nonisolated static let toolsTabID = "com.coffic.lumi.plugin.git.tools"

    public var name: String {
        LumiPluginLocalization.string("Git", bundle: .module)
    }
    public let order = 11
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .development
    public let stage: LumiPluginStage = .beta
    public let pluginDescription = "Git integration: history, commit details, branches, diffs."

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        // Phase 7 §15.6：注册 SCM 中立契约实现（编辑器侧消费者经服务注册表获取）。
        try kernel.registerService(SourceControlProviding.self, GitSourceControlAdapter())
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).title",
                title: name,
                placement: .center,
                order: 0
            ) {
                GitToolbarTitleView(containerID: self.id, kernel: kernel, title: self.name)
            },
        ]
    }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        guard let project = kernel.project else { return [] }
        return [
            PanelRailTabItem(
                id: Self.historyTabID,
                title: LumiPluginLocalization.string("History", bundle: .module),
                systemImage: "clock",
                visibility: .viewContainer(id: id),
                requiresProjectSupport: true
            ) {
                let gitVM = GitRuntimeBridge.gitVM
                GitCommitHistorySidebarView(project: project, gitVM: gitVM)
                    .environmentObject(gitVM)
            },
            PanelRailTabItem(
                id: Self.toolsTabID,
                title: LumiPluginLocalization.string("Tools", bundle: .module),
                systemImage: "wrench.and.screwdriver",
                visibility: .viewContainer(id: id),
                requiresProjectSupport: true
            ) {
                GitToolsHostView(project: project)
            },
        ]
    }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] {
        guard let project = kernel.project else { return [] }
        return [
            StatusBarItem(
                id: "\(id).stash",
                title: LumiPluginLocalization.string("Stashes", bundle: .module),
                systemImage: "tray.full",
                placement: .trailing,
                order: 100,
                statusBarView: {
                    AnyView(GitStatusBarVisibilityGate(containerID: self.id, kernel: kernel) {
                        GitStashStatusTile(
                            project: project,
                            onTap: { /* opening the panel is handled by the rail tab */ }
                        )
                    })
                }
            ),
            StatusBarItem(
                id: "\(id).gitignore",
                title: LumiPluginLocalization.string(".gitignore", bundle: .module),
                systemImage: "eye.slash",
                placement: .trailing,
                order: 101,
                statusBarView: {
                    AnyView(GitStatusBarVisibilityGate(containerID: self.id, kernel: kernel) {
                        GitIgnoreStatusTile(
                            project: project,
                            onTap: { }
                        )
                    })
                }
            ),
            StatusBarItem(
                id: "\(id).lfs",
                title: LumiPluginLocalization.string("Git LFS", bundle: .module),
                systemImage: "externaldrive",
                placement: .trailing,
                order: 102,
                statusBarView: {
                    AnyView(GitStatusBarVisibilityGate(containerID: self.id, kernel: kernel) {
                        GitLFSStatusTile(
                            project: project,
                            onTap: { }
                        )
                    })
                }
            ),
            StatusBarItem(
                id: "\(id).submodule",
                title: LumiPluginLocalization.string("Submodules", bundle: .module),
                systemImage: "folder.badge.gearshape",
                placement: .trailing,
                order: 103,
                statusBarView: {
                    AnyView(GitStatusBarVisibilityGate(containerID: self.id, kernel: kernel) {
                        GitSubmoduleStatusTile(
                            project: project,
                            onTap: { }
                        )
                    })
                }
            ),
            StatusBarItem(
                id: "\(id).conflict",
                title: LumiPluginLocalization.string("Merge conflicts", bundle: .module),
                systemImage: "exclamationmark.triangle",
                placement: .trailing,
                order: 104,
                statusBarView: {
                    AnyView(GitStatusBarVisibilityGate(containerID: self.id, kernel: kernel) {
                        GitConflictStatusTile(
                            project: project,
                            onTap: { }
                        )
                    })
                }
            ),
            StatusBarItem(
                id: "\(id).autopush",
                title: LumiPluginLocalization.string("Auto Push", bundle: .module),
                systemImage: "arrow.up.to.line",
                placement: .trailing,
                order: 105,
                statusBarView: {
                    AnyView(GitStatusBarVisibilityGate(containerID: self.id, kernel: kernel) {
                        AutoPushStatusTile(onTap: { })
                    })
                }
            ),
        ]
    }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        guard let project = kernel.project else { return [] }
        return [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "arrow.triangle.branch",
                supportsProject: true,
                railVisibility: .alwaysVisible,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ) {
                GitPanelHostView(project: project)
            },
        ]
    }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(GitPluginAboutView())
    }
    public func pluginManualView(kernel: KernelLumi) -> AnyView? {
        AnyView(GitManualView())
    }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [
            GitBranchTool(),
            GitCommitTool(),
            GitDiffTool(),
            GitLogTool(),
            GitShowTool(),
            GitStatusTool(),
            GitUnpushedTool(),
        ]
    }
}
