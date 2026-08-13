import Foundation
import SwiftUI
@testable import KernelLumi

/// 测试用 `LumiPlugin`,所有贡献方法返回空,仅可配置 id/order/policy
/// 与编辑器运行时插件。用于测试 `BuiltinPluginManager` 的贡献收集/排序/装配。
@MainActor
final class MockLumiPlugin: LumiPlugin {
    let id: String
    let name: String
    let order: Int
    let policy: LumiPluginPolicy
    private let editorRuntimePlugins: [any EditorPlugin]
    private let commandGroups: [CommandMenuGroup]

    init(
        id: String,
        name: String? = nil,
        order: Int,
        policy: LumiPluginPolicy = .alwaysOn,
        editorRuntimePlugins: [any EditorPlugin] = [],
        commandGroups: [CommandMenuGroup] = []
    ) {
        self.id = id
        self.name = name ?? id
        self.order = order
        self.policy = policy
        self.editorRuntimePlugins = editorRuntimePlugins
        self.commandGroups = commandGroups
    }

    func onBoot(kernel: KernelLumi) async throws {}
    func onReady(kernel: KernelLumi) async throws {}
    func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    func commandMenuGroups(kernel: KernelLumi) -> [CommandMenuGroup] { commandGroups }
    func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    func editorPlugins(kernel: KernelLumi) -> [any EditorPlugin] { editorRuntimePlugins }
}
