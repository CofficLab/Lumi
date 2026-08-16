import os
import SwiftUI
import KernelLumi
import SuperLogKit

@MainActor
public final class ProjectOverviewPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project-overview")

    public let id = "ProjectOverview"
    public var name: String {
        PluginProjectOverviewLocalization.string("ProjectOverview")
    }
    public let order = 14
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {}

    // MARK: - Agent Tools

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [ProjectOverviewTool()]
    }

    // MARK: - Prompt Suggestions

    /// 贡献聊天起始提示词，供消息列表空态展示。
    ///
    /// 本插件为 `alwaysOn` 且无独立视图容器，因此仅声明 `prompt`（不声明 `action`）：
    /// 点击时直接将该提示词作为消息发送，由 LLM 调用 `project_overview` 工具生成概览。
    /// 概览依赖项目文件，仅在已选择项目时展示（`onlyWithProject`）。
    public func promptSuggestions(kernel: KernelLumi) -> [LumiPromptSuggestion] {
        [
            LumiPromptSuggestion(
                id: "\(id).overview",
                title: PluginProjectOverviewLocalization.string("Prompt.Suggestion.Overview"),
                systemImage: "doc.text.magnifyingglass",
                visibility: .onlyWithProject
            )
        ]
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
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
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
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
