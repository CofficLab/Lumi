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
    func addRailItems(context: PluginContext) -> [RailItem] {
        Packaged.shared.addRailItems(context: context).map(RailItem.init(package:))
    }

    @MainActor
    func addSidebarSections(context: PluginContext) -> [AnyView] {
        Packaged.shared.addSidebarSections(context: context)
    }

    @MainActor
    func addSidebarBottomSections(context: PluginContext) -> [AnyView] {
        Packaged.shared.addSidebarBottomSections(context: context)
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

    @MainActor
    func configureRuntime(context: PluginRuntimeContext) {
        Packaged.shared.configureRuntime(context: context)
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

/// Type-erased bridge for plugins supplied by `LumiPluginRegistry`.
///
/// The app-side `SuperPlugin` still exposes static metadata for legacy local
/// plugins. Packaged plugins are delivered as existential instances, so this
/// adapter forwards metadata through instance-level properties instead.
actor AnyPackagePluginAdapter: SuperPlugin {
    static let shared = AnyPackagePluginAdapter(packaged: EmptyPackagedPlugin.shared)

    static var id: String { "AnyPackagePluginAdapter" }
    static var displayName: String { "Package Plugin" }
    static var description: String { "" }
    static var iconName: String { "puzzlepiece" }
    static var policy: PluginPolicy { .disabled }
    static var category: PluginCategory { .general }
    static var order: Int { Int.max }

    private let packaged: any LumiCoreKit.SuperPlugin

    init(packaged: any LumiCoreKit.SuperPlugin) {
        self.packaged = packaged
    }

    nonisolated var instanceLabel: String { packaged.instanceLabel }
    nonisolated var pluginID: String { type(of: packaged).id }
    nonisolated var pluginDisplayName: String { type(of: packaged).displayName }
    nonisolated var pluginDescription: String { type(of: packaged).description }
    nonisolated var pluginIconName: String { type(of: packaged).iconName }
    nonisolated var pluginPolicy: PluginPolicy { type(of: packaged).policy }
    nonisolated var pluginCategory: PluginCategory { PluginCategory(package: type(of: packaged).category) }
    nonisolated var pluginOrder: Int { type(of: packaged).order }

    nonisolated func pluginDescription(for language: LanguagePreference) -> String {
        type(of: packaged).description(for: language)
    }

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        packaged.addRootView(content: content)
    }

    @MainActor
    func wrapRightSidebarRoot(_ content: AnyView, context: PluginContext) -> AnyView {
        packaged.wrapRightSidebarRoot(content, context: context)
    }

    @MainActor
    func addToolBarLeadingView(context: PluginContext) -> AnyView? {
        packaged.addToolBarLeadingView(context: context)
    }

    @MainActor
    func addToolBarCenterView(context: PluginContext) -> AnyView? {
        packaged.addToolBarCenterView(context: context)
    }

    @MainActor
    func addToolBarTrailingView(context: PluginContext) -> AnyView? {
        packaged.addToolBarTrailingView(context: context)
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        packaged.addViewContainer().map(ViewContainerItem.init(package:))
    }

    @MainActor
    func addPanelHeaderView(context: PluginContext) -> AnyView? {
        packaged.addPanelHeaderView(context: context)
    }

    @MainActor
    func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] {
        packaged.addBottomPanelTabs(context: context).map(BottomPanelTab.init(package:))
    }

    @MainActor
    func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? {
        packaged.addBottomPanelContentView(tabId: tabId, context: context)
    }

    @MainActor
    func addRailItems(context: PluginContext) -> [RailItem] {
        packaged.addRailItems(context: context).map(RailItem.init(package:))
    }

    @MainActor
    func addSidebarSections(context: PluginContext) -> [AnyView] {
        packaged.addSidebarSections(context: context)
    }

    @MainActor
    func addSidebarBottomSections(context: PluginContext) -> [AnyView] {
        packaged.addSidebarBottomSections(context: context)
    }

    @MainActor
    func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        packaged.addSidebarLeadingToolbarItems(context: context).map(SidebarToolbarItem.init(package:))
    }

    @MainActor
    func addSidebarTrailingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        packaged.addSidebarTrailingToolbarItems(context: context).map(SidebarToolbarItem.init(package:))
    }

    @MainActor
    func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        packaged.addSidebarToolbarItemView(itemId: itemId, context: context)
    }

    @MainActor
    func addSettingsView() -> AnyView? {
        packaged.addSettingsView()
    }

    @MainActor
    func addPosterViews() -> [AnyView] {
        packaged.addPosterViews()
    }

    @MainActor
    func addMenuBarPopupViews() -> [AnyView] {
        packaged.addMenuBarPopupViews()
    }

    @MainActor
    func addMenuBarContentView() -> AnyView? {
        packaged.addMenuBarContentView()
    }

    @MainActor
    func addStatusBarLeadingView(context: PluginContext) -> AnyView? {
        packaged.addStatusBarLeadingView(context: context)
    }

    @MainActor
    func addStatusBarCenterView(context: PluginContext) -> AnyView? {
        packaged.addStatusBarCenterView(context: context)
    }

    @MainActor
    func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        packaged.addStatusBarTrailingView(context: context)
    }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        packaged.addThemeContributions()
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        packaged.agentTools(context: context.packageContext)
    }

    @MainActor
    func subAgentDefinitions() -> [any SubAgentDefinitionProtocol] {
        packaged.subAgentDefinitions()
    }

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        packaged.sendMiddlewares().map(AnySuperSendMiddleware.init)
    }

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        packaged.llmProviderType()
    }

    @MainActor
    func messageRenderers() -> [any SuperMessageRenderer] {
        packaged.messageRenderers().map(PackageMessageRendererAdapter.init)
    }

    nonisolated var providesEditorExtensions: Bool {
        packaged.providesEditorExtensions
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        packaged.registerEditorExtensions(into: registry)
    }

    @MainActor
    func configureRuntime(context: PluginRuntimeContext) {
        packaged.configureRuntime(context: context)
    }

    nonisolated func onRegister() {
        packaged.onRegister()
    }

    nonisolated func onEnable() {
        packaged.onEnable()
    }

    nonisolated func onDisable() {
        packaged.onDisable()
    }
}

private actor EmptyPackagedPlugin: LumiCoreKit.SuperPlugin {
    static let shared = EmptyPackagedPlugin()
    static let policy: LumiCoreKit.PluginPolicy = .disabled
    static let category: LumiCoreKit.PluginCategory = .general
}
