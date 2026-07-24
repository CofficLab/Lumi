import Foundation
import LumiKernel
import os
import SuperLogKit
import SwiftUI

@MainActor
public final class ProjectsPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects")
    public nonisolated static let emoji = "📂"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.projects"
    public let name = "Projects Plugin"
    public let order = 20
    public let policy: LumiPluginPolicy = .alwaysOn // 核心插件

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        try await ProjectsOnBootHook().execute(kernel)
    }

    public func onReady(kernel: LumiKernel) async throws {
        // 1. 初始化存储
        guard let storage = kernel.storage else {
            Self.logger.error("📂 Storage service not available，跳过 Projects 插件初始化")
            return
        }
        let storageDirectory = storage.pluginDataDirectory(for: "Projects")
        let store = ProjectsStore(pluginDirectory: storageDirectory)

        if Self.verbose {
            Self.logger.info("📂 Initialized ProjectsStore")
        }

        // 迁移 v4 历史项目(必须在 ViewModel 初始化之前完成 —— ViewModel init 时会
        // loadProjects,此时 projects.json 应已含合并后的数据)。幂等 + 吞错。
        ProjectsLegacyMigration(currentDataRootDirectory: storage.dataRootDirectory, store: store).run()

        // 2. 初始化 ViewModel
        let viewModel = ProjectsViewModel(store: store)

        if Self.verbose {
            Self.logger.info("📂 Initialized ProjectsViewModel")
        }

        // 3. 初始化同步协调器
        let coordinator = ProjectsSyncCoordinator(viewModel: viewModel)
        coordinator.kernel = kernel

        if Self.verbose {
            Self.logger.info("📂 Initialized ProjectsSyncCoordinator")
        }

        // 4. 设置 RuntimeBridge — 供 Agent 工具使用，并供
        //    `titleToolbarItems(kernel:)` 声明式访问 viewModel（在 onReady 之后
        //    由 BuiltinPluginManager.registerPluginUIContributions 收集）。
        ProjectsToolRuntimeBridge.viewModel = viewModel

        if Self.verbose {
            Self.logger.info("📂 Projects 插件 onReady 完成")
        }
    }

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
            ListProjectsTool(),
            AddProjectTool(),
            GetCurrentProjectTool(),
        ]
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func willSendToLLM(kernel: LumiKernel, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        await ProjectsWillSendToLLMHook(pluginID: id).execute(kernel: kernel, messages: messages)
    }

    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] {
        guard let viewModel = ProjectsToolRuntimeBridge.viewModel else {
            return []
        }

        return [
            LumiTitleToolbarItem(
                id: "\(id).toolbar",
                title: "Projects",
                placement: .center
            ) {
                ProjectControlView(viewModel: viewModel)
            }
        ]
    }

    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility { WorkspaceVisibility() }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
