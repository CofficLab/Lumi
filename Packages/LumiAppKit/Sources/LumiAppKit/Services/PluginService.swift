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
/// - 协议实现（LumiAgentToolProviding、LumiChatContributionProviding、LumiLLMProviderSettingsContributing）
@MainActor
final class PluginService: ObservableObject, SuperLog, AgentToolProviding, LumiChatContributionProviding, LumiLLMProviderSettingsContributing {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.plugin")
    nonisolated static let emoji = "🔌"
    nonisolated static let verbose = false

    init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化 PluginService")
        }

        // 抢在首帧渲染之前恢复 LayoutPlugin 的持久化布局状态（时序敏感：
        // 若晚于 AppLayoutView.onAppear，默认 containers[0] 会先落盘覆盖持久化值）。
        // 幂等——后续 .appDidLaunch 二次调用为 no-op。
        LumiPluginRegistry.restoreLayoutEarly()

        // 初始化状态管理器
        LumiPluginRegistry.initializeStateManager()

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 \(LumiPluginRegistry.registeredPlugins.count) 个插件")
        }

        // 初始化插件启用状态（覆盖 overrides 合并等）
        LumiPluginRegistry.initializePluginStates()

        // 订阅插件启用状态变化：触发 SwiftUI 刷新。
        // 与 NotificationCenter 广播并存——闭包槽用于本类的 UI 刷新，
        // Notification 供其他服务各自订阅自己的刷新逻辑。
        LumiPluginRegistry.onEnabledPluginsChanged = { [weak self] in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Hooks

    /// 工具执行后的钩子闭包，供 `ChatService.applyPluginContributions(toolExecutionHook:)` 注入。
    ///
    /// 这是 App 层对 `LumiPluginRegistry` 的反向桥接——询问实现了 `LumiToolExecutionHook`
    /// 的插件是否需要在工具执行后暂停 Agent 循环（如 ask_user 等待用户回答）。
    /// 任意插件返回 `true` 即视为需要暂停。
    var toolExecutionHook: (String, String, UUID) async -> Bool {
        { toolName, result, conversationID in
            await LumiPluginRegistry.dispatchToolExecution(
                toolName: toolName,
                result: result,
                conversationID: conversationID
            )
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

    func titleToolbarItems(lumiCore: any LumiCoreAccessing) -> [LumiTitleToolbarItem] {
        LumiPluginRegistry.titleToolbarItems(lumiCore: lumiCore)
    }

    func statusBarItems(lumiCore: any LumiCoreAccessing) -> [LumiStatusBarItem] {
        LumiPluginRegistry.statusBarItems(lumiCore: lumiCore)
    }

    func viewContainers(lumiCore: any LumiCoreAccessing) -> [LumiViewContainerItem] {
        LumiPluginRegistry.viewContainers(lumiCore: lumiCore)
    }

    func menuBarContentItems(lumiCore: any LumiCoreAccessing) -> [LumiMenuBarContentItem] {
        LumiPluginRegistry.menuBarContentItems(lumiCore: lumiCore)
    }

    func menuBarPopupItems(lumiCore: any LumiCoreAccessing) -> [LumiMenuBarPopupItem] {
        LumiPluginRegistry.menuBarPopupItems(lumiCore: lumiCore)
            .sorted { $0.order < $1.order }
    }

    func llmProviders(lumiCore: any LumiCoreAccessing) -> [any LumiLLMProvider] {
        LumiPluginRegistry.llmProviders(lumiCore: lumiCore)
    }

    func agentTools(lumiCore: any LumiCoreAccessing) -> [any LumiAgentTool] {
        LumiPluginRegistry.agentTools(lumiCore: lumiCore)
    }

    func lastAgentToolFailures() -> [LumiPluginContributionFailure] {
        LumiPluginRegistry.agentToolFailures
    }

    func subAgents(lumiCore: any LumiCoreAccessing) -> [LumiSubAgentDefinition] {
        LumiPluginRegistry.subAgents(lumiCore: lumiCore)
    }

    func sendMiddlewares(lumiCore: any LumiCoreAccessing) -> [any LumiSendMiddleware] {
        LumiPluginRegistry.sendMiddlewares(lumiCore: lumiCore)
    }

    func messageRenderers(lumiCore: any LumiCoreAccessing) -> [LumiMessageRendererItem] {
        LumiPluginRegistry.messageRenderers(lumiCore: lumiCore)
    }

    func rootOverlays(lumiCore: any LumiCoreAccessing) -> [LumiRootOverlayItem] {
        LumiPluginRegistry.rootOverlays(lumiCore: lumiCore)
    }

    func onboardingPages(lumiCore: any LumiCoreAccessing) -> [OnboardingPageView] {
        LumiPluginRegistry.onboardingPages(lumiCore: lumiCore)
    }

    func chatSectionItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionItem] {
        LumiPluginRegistry.chatSectionItems(lumiCore: lumiCore)
    }

    func chatSectionRootWrapper(lumiCore: any LumiCoreAccessing, content: AnyView) -> AnyView {
        LumiPluginRegistry.chatSectionRootWrapper(lumiCore: lumiCore, content: content)
    }

    func chatSectionToolbarItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionToolbarItem] {
        LumiPluginRegistry.chatSectionToolbarItems(lumiCore: lumiCore)
    }

    func chatSectionToolbarBarItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionToolbarBarItem] {
        LumiPluginRegistry.chatSectionToolbarBarItems(lumiCore: lumiCore)
    }

    func chatSectionHeaderItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionHeaderItem] {
        LumiPluginRegistry.chatSectionHeaderItems(lumiCore: lumiCore)
    }

    func panelHeaderItems(lumiCore: any LumiCoreAccessing) -> [LumiPanelHeaderItem] {
        LumiPluginRegistry.panelHeaderItems(lumiCore: lumiCore)
    }

    func panelBottomTabItems(lumiCore: any LumiCoreAccessing) -> [LumiPanelBottomTabItem] {
        LumiPluginRegistry.panelBottomTabItems(lumiCore: lumiCore)
    }

    func panelRailTabItems(lumiCore: any LumiCoreAccessing) -> [LumiPanelRailTabItem] {
        LumiPluginRegistry.panelRailTabItems(lumiCore: lumiCore)
    }

    func llmProviderSettingsViews(lumiCore: any LumiCoreAccessing) -> [LumiLLMProviderSettingsViewItem] {
        LumiPluginRegistry.llmProviderSettingsViews(lumiCore: lumiCore)
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

    func registerPluginContributions(lumiCore: any LumiCoreAccessing) {
        let allItems = LumiPluginRegistry.logoItems(lumiCore: lumiCore)

        if Self.verbose {
            Self.logger.info("\(Self.t)注册了 \(allItems.count) 个 Logo 贡献")
        }

        lumiCore.logoComponent.register(allItems)
    }

    func onTurnFinished(lumiCore: any LumiCoreAccessing, conversationID: UUID, reason: LumiTurnEndReason) async {
        await LumiPluginRegistry.onTurnFinished(
            lumiCore: lumiCore,
            conversationID: conversationID,
            reason: reason
        )
    }
}
