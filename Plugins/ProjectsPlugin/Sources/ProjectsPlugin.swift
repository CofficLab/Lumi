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
    public let order = 5
    public let policy: LumiPluginPolicy = .alwaysOn // 核心插件

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        try await ProjectsOnBootHook().execute(kernel)
    }

    public func onReady(kernel: LumiKernel) async throws {
        try await ProjectsOnReadyHook(pluginID: id).execute(kernel)
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
        guard let viewModel = RuntimeBridge.viewModel else {
            return []
        }

        return [
            LumiTitleToolbarItem(
                id: "\(id).toolbar",
                title: "Projects",
                placement: .center,
                order: 0
            ) {
                ControlView(viewModel: viewModel)
            },
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
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
        guard let viewModel = RuntimeBridge.viewModel else {
            return []
        }
        return [
            SettingsTabItem(
                id: "\(id).settings",
                title: LumiPluginLocalization.string("Projects", bundle: .module),
                systemImage: "folder",
                order: order
            ) {
                SettingsView(viewModel: viewModel)
            },
        ]
    }

    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
