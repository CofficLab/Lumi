import Foundation
import LumiKernel
import SwiftUI

/// 通用子 Agent 提供插件
///
/// 贡献一组**继承主 Agent 当前选中供应商/模型**的内置通用子 Agent
/// （Explore / Code Review / Bug Fixer / Test Writer）。
///
/// 与 `LLMProviderStepFunPlugin` 的固定供应商子 Agent 不同，本插件提供的子 Agent
/// 通过 `LumiSubAgentDefinition.inheritsSelectedProvider = true`，在执行时现查
/// 主 Agent 当前选中的 provider/model。这样无论 StepFun 是否可用，只要用户选了
/// 任意支持工具调用的模型，就始终有子 Agent 可用。
///
/// 子 Agent 经由框架的 `SubAgentRouterTool`（`delegate_task` 工具）按关键词路由派发，
/// 本插件不直接注册任何工具或 UI。
@MainActor
public final class SubAgentProviderPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.sub-agent-provider"
    public let name = "Sub-Agent Provider"
    public let order = 220
    public let policy: LumiPluginPolicy = .alwaysOn
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .stable
    public let pluginDescription = """
    Provides built-in general-purpose sub-agents (Explore, Code Review, Bug Fixer, Test \
    Writer) that run on the host's currently selected provider and model, so delegation is \
    always available even when StepFun is offline.
    """

    public init() {}

    // MARK: - Lifecycle

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}

    // MARK: - Sub-Agents

    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] {
        [
            ExploreAgent.definition,
            CodeReviewAgent.definition,
            BugFixerAgent.definition,
            TestWriterAgent.definition
        ]
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
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
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
    public func editorPlugins(kernel: LumiKernel) -> [any EditorPlugin] { [] }
}
