import LumiKernel
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
    public var name: String {
        LumiPluginLocalization.string("Git", bundle: .module)
    }
    public let order = 11
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .development
    public let stage: LumiPluginStage = .beta
    public let pluginDescription = "Git integration: history, commit details, branches, diffs."

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).title",
                title: name,
                placement: .center,
                order: 0
            ) {
                Text(self.name)
                    .font(.system(size: 13, weight: .semibold))
            },
        ]
    }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        guard let project = kernel.project else { return [] }
        return [
            PanelRailTabItem(
                id: "\(id).history",
                title: LumiPluginLocalization.string("History", bundle: .module),
                systemImage: "clock",
                visibility: .viewContainer(id: id),
                requiresProjectSupport: true
            ) {
                let gitVM = GitRuntimeBridge.gitVM
                GitCommitHistorySidebarView(project: project, gitVM: gitVM)
                    .environmentObject(gitVM)
            },
        ]
    }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
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
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
        public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Label(LumiPluginLocalization.string("Git", bundle: .module),
                      systemImage: "arrow.triangle.branch")
                    .font(.headline)
                Text(LumiPluginLocalization.string("Git version control integration with history view.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
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
