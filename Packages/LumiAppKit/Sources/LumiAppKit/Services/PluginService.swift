import EditorService
import LumiCoreKit
import LumiPluginRegistry
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// 插件服务 - App 层的 ObservableObject 适配器
///
/// 实际逻辑委托给 LumiPluginRegistry，本类仅负责：
/// - ObservableObject 支持（UI 刷新）
/// - 协议实现（LumiAgentToolProviding、LumiLLMProviderSettingsContributing）
@MainActor
final class PluginService: ObservableObject, SuperLog, LumiAgentToolProviding, LumiLLMProviderSettingsContributing {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.plugin")
    nonisolated static let emoji = "🔌"
    nonisolated static let verbose = false

    init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化 PluginService")
        }

        // 初始化状态管理器
        LumiPluginRegistry.initializeStateManager()

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 \(LumiPluginRegistry.registeredPlugins.count) 个插件")
        }

        // 设置回调，触发 UI 刷新
        LumiPluginRegistry.onEnabledPluginsChanged = { [weak self] in
            self?.objectWillChange.send()
        }

        // 统一触发插件生命周期事件
        Task { @MainActor in
            await LumiPluginRegistry.registerAll()
            await LumiPluginRegistry.appDidLaunch()
        }
    }

    // MARK: - 委托到 LumiPluginRegistry

    var plugins: [any LumiPlugin.Type] {
        LumiPluginRegistry.registeredPlugins
    }

    var enabledPlugins: [any LumiPlugin.Type] {
        LumiPluginRegistry.enabledPlugins
    }

    var editorExtensionPlugins: [any LumiPlugin.Type] {
        LumiPluginRegistry.editorExtensionPlugins
    }

    var enabledEditorExtensionPluginIDs: Set<String> {
        LumiPluginRegistry.enabledEditorExtensionPluginIDs
    }

    func isPluginEnabled(_ plugin: any LumiPlugin.Type) -> Bool {
        LumiPluginRegistry.isPluginEnabled(plugin)
    }

    func eligibility(for plugin: any LumiPlugin.Type) -> LumiPluginEligibility {
        LumiPluginRegistry.eligibility(for: plugin)
    }

    func setPlugin(_ plugin: any LumiPlugin.Type, enabled: Bool) {
        LumiPluginRegistry.setPlugin(plugin, enabled: enabled)
        objectWillChange.send()
    }

    func getPluginEnabledState(_ plugin: any LumiPlugin.Type) -> Bool {
        LumiPluginRegistry.getPluginEnabledState(plugin)
    }

    func initializePluginStates() {
        LumiPluginRegistry.initializePluginStates()
    }

    // MARK: - 聚合方法（委托）

    func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        LumiPluginRegistry.titleToolbarItems(context: context)
    }

    func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        LumiPluginRegistry.statusBarItems(context: context)
    }

    func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        LumiPluginRegistry.viewContainers(context: context)
    }

    func menuBarContentItems(context: LumiPluginContext) -> [LumiMenuBarContentItem] {
        LumiPluginRegistry.menuBarContentItems(context: context)
    }

    func menuBarPopupItems(context: LumiPluginContext) -> [LumiMenuBarPopupItem] {
        LumiPluginRegistry.menuBarPopupItems(context: context)
    }

    func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        LumiPluginRegistry.llmProviders(context: context)
    }

    func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        LumiPluginRegistry.agentTools(context: context)
    }

    func subAgents(context: LumiPluginContext) -> [LumiSubAgentDefinition] {
        LumiPluginRegistry.subAgents(context: context)
    }

    func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        LumiPluginRegistry.sendMiddlewares(context: context)
    }

    func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        LumiPluginRegistry.messageRenderers(context: context)
    }

    func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        LumiPluginRegistry.rootOverlays(context: context)
    }

    func onboardingPages(context: LumiPluginContext) -> [OnboardingPageView] {
        LumiPluginRegistry.onboardingPages(context: context)
    }

    func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem] {
        LumiPluginRegistry.chatSectionItems(context: context)
    }

    func chatSectionRootWrapper(context: LumiPluginContext, content: AnyView) -> AnyView {
        LumiPluginRegistry.chatSectionRootWrapper(context: context, content: content)
    }

    func chatSectionToolbarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarItem] {
        LumiPluginRegistry.chatSectionToolbarItems(context: context)
    }

    func chatSectionToolbarBarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarBarItem] {
        LumiPluginRegistry.chatSectionToolbarBarItems(context: context)
    }

    func chatSectionHeaderItems(context: LumiPluginContext) -> [LumiChatSectionHeaderItem] {
        LumiPluginRegistry.chatSectionHeaderItems(context: context)
    }

    func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem] {
        LumiPluginRegistry.panelHeaderItems(context: context)
    }

    func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
        LumiPluginRegistry.panelBottomTabItems(context: context)
    }

    func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        LumiPluginRegistry.panelRailTabItems(context: context)
    }

    func llmProviderSettingsViews(context: LumiPluginContext) -> [LumiLLMProviderSettingsViewItem] {
        LumiPluginRegistry.llmProviderSettingsViews(context: context)
    }

    func themeContributions() -> [LumiUIThemeContribution] {
        enabledPlugins.flatMap { plugin -> [LumiUIThemeContribution] in
            guard let provider = plugin as? any LumiUIThemeProviding.Type else {
                return []
            }

            return provider.themeContributions().map { contribution in
                LumiUIThemeContribution(
                    sortKey: ThemeSortKey(
                        pluginOrder: plugin.info.order,
                        themeId: contribution.id
                    ),
                    chromeTheme: contribution.chromeTheme,
                    editorThemeId: contribution.editorThemeId,
                    uiTheme: contribution.uiTheme,
                    attachments: contribution.attachments
                )
            }
        }
    }

    func registerPluginContributions(context: LumiPluginContext) {
        let allItems = LumiPluginRegistry.logoItems(context: context)

        if Self.verbose {
            Self.logger.info("\(Self.t)注册了 \(allItems.count) 个 Logo 贡献")
        }

        LogoRegistry.shared.register(allItems)
    }

    func onTurnFinished(conversationID: UUID, reason: LumiTurnEndReason) async {
        await LumiPluginRegistry.onTurnFinished(
            context: createPluginContext(),
            conversationID: conversationID,
            reason: reason
        )
    }
}
