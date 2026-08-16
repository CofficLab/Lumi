import Foundation
import SwiftUI
@testable import KernelLumi

/// 测试用 `LumiPlugin`,所有贡献方法返回空,仅可配置 id/order/policy
/// 与编辑器贡献包。用于测试 `BuiltinPluginManager` 的贡献收集/排序/装配。
@MainActor
final class MockLumiPlugin: LumiPlugin {
    let id: String
    let name: String
    let order: Int
    let policy: LumiPluginPolicy
    let stage: LumiPluginStage
    private let editorBundle: EditorContributionBundle?
    private let commandGroups: [CommandMenuGroup]
    private let promptSuggestionItems: [LumiPromptSuggestion]

    init(
        id: String,
        name: String? = nil,
        order: Int,
        policy: LumiPluginPolicy = .alwaysOn,
        editorBundle: EditorContributionBundle? = nil,
        commandGroups: [CommandMenuGroup] = [],
        promptSuggestions: [LumiPromptSuggestion] = []
    ) {
        self.id = id
        self.name = name ?? id
        self.order = order
        self.policy = policy
        self.stage = .stable
        self.editorBundle = editorBundle
        self.commandGroups = commandGroups
        self.promptSuggestionItems = promptSuggestions
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
    func promptSuggestions(kernel: KernelLumi) -> [LumiPromptSuggestion] { promptSuggestionItems }
    func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    func editorContributionBundle(kernel: KernelLumi) async throws -> EditorContributionBundle? { editorBundle }
}
