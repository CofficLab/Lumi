import Foundation
import KernelLumi
import os
import SuperLogKit
import SwiftUI

@MainActor
public final class ProjectsPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects")
    public nonisolated static let emoji = "📂"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.projects"
    public var name: String {
        LumiPluginLocalization.string("Projects Plugin", bundle: .module)
    }

    public let order = 5
    public let policy: LumiPluginPolicy = .alwaysOn // 核心插件
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        try await ProjectsOnBootHook().execute(kernel)
    }

    public func onReady(kernel: KernelLumi) async throws {
        try await ProjectsOnReadyHook(pluginID: id).execute(kernel)
    }

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [
            ListProjectsTool(),
            AddProjectTool(),
            GetCurrentProjectTool(),
        ]
    }

    /// 贡献「添加项目」动作胶囊：仅在无当前项目时与提示词并列展示，
    /// 点击打开文件夹选择器（终端动作，不发送消息）。
    public func promptSuggestions(kernel: KernelLumi) -> [LumiPromptSuggestion] {
        [
            LumiPromptSuggestion(
                id: "\(id).add",
                title: LumiPluginLocalization.string("Add Project", bundle: .module),
                systemImage: "folder.badge.plus",
                action: .pickProjectFolder,
                visibility: .onlyWithoutProject,
                style: .additive
            ),
        ]
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func willSendToLLM(kernel: KernelLumi, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        await ProjectsWillSendToLLMHook(pluginID: id).execute(kernel: kernel, messages: messages)
    }

    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
        guard let viewModel = RuntimeBridge.viewModel else {
            return []
        }

        return [
            LumiTitleToolbarItem(
                id: "\(id).toolbar",
                title: LumiPluginLocalization.string("Projects", bundle: .module),
                placement: .center,
                order: 0
            ) {
                ControlView(viewModel: viewModel, kernel: kernel)
            },
        ]
    }

    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] {
        guard let viewModel = RuntimeBridge.viewModel else {
            return []
        }
        return [
            SettingsTabItem(
                id: LumiSettingsTabID.projects,
                title: LumiPluginLocalization.string("Projects", bundle: .module),
                systemImage: "folder",
                order: order
            ) {
                SettingsView(viewModel: viewModel, kernel: kernel)
            },
        ]
    }

    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
