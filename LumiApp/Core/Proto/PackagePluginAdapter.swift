import EditorService
import Foundation
import AgentToolKit
import LumiCoreKit
import SwiftUI

/// Bridges package-native plugins into the app plugin protocol.
///
/// Package plugins conform to `LumiCoreKit.SuperPlugin`, while the app target
/// still owns a compatibility `SuperPlugin` protocol for local UI structs.
/// This adapter lets generated registration include package plugins without
/// requiring one handwritten app-side wrapper per plugin.
actor PackagePluginAdapter<Packaged: LumiCoreKit.SuperPlugin>: SuperPlugin {
    static var shared: PackagePluginAdapter<Packaged> {
        PackagePluginAdapter()
    }

    static var id: String { Packaged.id }
    static var displayName: String { Packaged.displayName }
    static var description: String { Packaged.description }
    static var iconName: String { Packaged.iconName }
    static var policy: PluginPolicy { Packaged.policy }
    static var category: PluginCategory { PluginCategory(package: Packaged.category) }
    static var order: Int { Packaged.order }

    static func description(for language: LanguagePreference) -> String {
        Packaged.description(for: language)
    }

    nonisolated var instanceLabel: String { Packaged.shared.instanceLabel }

    private init() {}

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        Packaged.shared.addRootView(content: content)
    }

    @MainActor
    func wrapRightSidebarRoot(_ content: AnyView, context: PluginContext) -> AnyView {
        Packaged.shared.wrapRightSidebarRoot(content, context: context)
    }

    @MainActor
    func addToolBarLeadingView(context: PluginContext) -> AnyView? {
        Packaged.shared.addToolBarLeadingView(context: context)
    }

    @MainActor
    func addToolBarCenterView(context: PluginContext) -> AnyView? {
        Packaged.shared.addToolBarCenterView(context: context)
    }

    @MainActor
    func addToolBarTrailingView(context: PluginContext) -> AnyView? {
        Packaged.shared.addToolBarTrailingView(context: context)
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        Packaged.shared.addViewContainer().map(ViewContainerItem.init(package:))
    }

    @MainActor
    func addPanelHeaderView(context: PluginContext) -> AnyView? {
        Packaged.shared.addPanelHeaderView(context: context)
    }

    @MainActor
    func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] {
        Packaged.shared.addBottomPanelTabs(context: context).map(BottomPanelTab.init(package:))
    }

    @MainActor
    func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? {
        Packaged.shared.addBottomPanelContentView(tabId: tabId, context: context)
    }

    @MainActor
    func addRailTabs(context: PluginContext) -> [RailTab] {
        Packaged.shared.addRailTabs(context: context).map(RailTab.init(package:))
    }

    @MainActor
    func addRailContentView(tabId: String, context: PluginContext) -> AnyView? {
        Packaged.shared.addRailContentView(tabId: tabId, context: context)
    }

    @MainActor
    func addSidebarSections(context: PluginContext) -> [AnyView] {
        Packaged.shared.addSidebarSections(context: context)
    }

    @MainActor
    func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        Packaged.shared.addSidebarLeadingToolbarItems(context: context).map(SidebarToolbarItem.init(package:))
    }

    @MainActor
    func addSidebarTrailingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        Packaged.shared.addSidebarTrailingToolbarItems(context: context).map(SidebarToolbarItem.init(package:))
    }

    @MainActor
    func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        Packaged.shared.addSidebarToolbarItemView(itemId: itemId, context: context)
    }

    @MainActor
    func addSettingsView() -> AnyView? {
        Packaged.shared.addSettingsView()
    }

    @MainActor
    func addPosterViews() -> [AnyView] {
        Packaged.shared.addPosterViews()
    }

    @MainActor
    func addMenuBarPopupViews() -> [AnyView] {
        Packaged.shared.addMenuBarPopupViews()
    }

    @MainActor
    func addMenuBarContentView() -> AnyView? {
        Packaged.shared.addMenuBarContentView()
    }

    @MainActor
    func addStatusBarLeadingView(context: PluginContext) -> AnyView? {
        Packaged.shared.addStatusBarLeadingView(context: context)
    }

    @MainActor
    func addStatusBarCenterView(context: PluginContext) -> AnyView? {
        Packaged.shared.addStatusBarCenterView(context: context)
    }

    @MainActor
    func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        Packaged.shared.addStatusBarTrailingView(context: context)
    }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        Packaged.shared.addThemeContributions()
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        Packaged.shared.agentTools(context: context.packageContext)
    }

    @MainActor
    func subAgentDefinitions() -> [any SubAgentDefinitionProtocol] {
        Packaged.shared.subAgentDefinitions()
    }

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        Packaged.shared.sendMiddlewares().map(AnySuperSendMiddleware.init)
    }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        Packaged.shared.llmProviderType()
    }

    @MainActor
    func messageRenderers() -> [any SuperMessageRenderer] {
        Packaged.shared.messageRenderers().map(PackageMessageRendererAdapter.init)
    }

    nonisolated var providesEditorExtensions: Bool {
        Packaged.shared.providesEditorExtensions
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        Packaged.shared.registerEditorExtensions(into: registry)
    }

    nonisolated func onRegister() {
        Packaged.shared.onRegister()
    }

    nonisolated func onEnable() {
        Packaged.shared.onEnable()
    }

    nonisolated func onDisable() {
        Packaged.shared.onDisable()
    }
}
