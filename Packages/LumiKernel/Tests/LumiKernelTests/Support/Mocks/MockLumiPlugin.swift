import Foundation
import SwiftUI
@testable import LumiKernel

/// 测试用 `LumiPlugin`,所有贡献方法返回空,仅可配置 id/order/policy
/// 与编辑器运行时插件。用于测试 `BuiltinPluginManager` 的贡献收集/排序/装配。
@MainActor
final class MockLumiPlugin: LumiPlugin {
    let id: String
    let name: String
    let order: Int
    let policy: LumiPluginPolicy
    private let editorRuntimePlugins: [any EditorPlugin]

    init(
        id: String,
        name: String? = nil,
        order: Int,
        policy: LumiPluginPolicy = .alwaysOn,
        editorRuntimePlugins: [any EditorPlugin] = []
    ) {
        self.id = id
        self.name = name ?? id
        self.order = order
        self.policy = policy
        self.editorRuntimePlugins = editorRuntimePlugins
    }

    func onBoot(kernel: LumiKernel) async throws {}
    func onReady(kernel: LumiKernel) async throws {}
    func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    func editorPlugins(kernel: LumiKernel) -> [any EditorPlugin] { editorRuntimePlugins }
}
