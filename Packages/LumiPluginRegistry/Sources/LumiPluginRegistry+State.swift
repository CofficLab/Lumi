import Foundation
import LumiCoreKit
import SwiftUI
import os

extension LumiPluginRegistry {
    // MARK: - 状态管理

    /// 插件启用状态覆盖配置
    private static var _enabledOverrides: [String: Bool] = [:]

    /// 插件启用状态跟踪
    private static var _pluginEnabledStates: [String: Bool] = [:]

    /// 设置存储
    private static let _settingsStore = PluginSettingsStore()

    /// 日志
    private static let _logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.state")

    /// 是否启用详细日志
    private static let _verbose = false

    /// 初始化状态管理器
    public static func initializeStateManager() {
        _enabledOverrides = _settingsStore.loadEnabledOverrides()
    }

    /// 检查插件是否启用
    public static func isPluginEnabled(_ plugin: any LumiPlugin.Type) -> Bool {
        eligibility(for: plugin).isEligible
    }

    /// 获取插件资格状态
    public static func eligibility(for plugin: any LumiPlugin.Type) -> LumiPluginEligibility {
        LumiPluginEligibility(
            policy: plugin.policy,
            userEnabled: userEnabledValue(for: plugin)
        )
    }

    /// 设置插件启用状态
    public static func setPlugin(_ plugin: any LumiPlugin.Type, enabled: Bool) {
        guard plugin.policy.isConfigurable else {
            if _verbose {
                _logger.info("插件 \(plugin.info.id) 不可配置")
            }
            return
        }

        let pluginId = plugin.info.id
        let previousState = _pluginEnabledStates[pluginId] ?? isPluginEnabled(plugin)

        if _verbose {
            _logger.info("设置插件 \(pluginId) -> \(enabled)")
        }

        // 如果从启用变为禁用，先触发 willDisable 生命周期
        if previousState && !enabled {
            Task {
                await plugin.lifecycle(.willDisable)
            }
        }

        _enabledOverrides[pluginId] = enabled
        _pluginEnabledStates[pluginId] = enabled
        _settingsStore.saveEnabledOverrides(_enabledOverrides)
        onEnabledPluginsChanged?()

        // 如果状态实际发生变化，触发生命周期回调
        if previousState != enabled {
            onPluginLifecycleChange?(plugin, enabled)
        }
    }

    /// 获取插件启用状态
    public static func getPluginEnabledState(_ plugin: any LumiPlugin.Type) -> Bool {
        _pluginEnabledStates[plugin.info.id] ?? isPluginEnabled(plugin)
    }

    /// 初始化所有插件状态
    public static func initializePluginStates() {
        if _verbose {
            _logger.info("初始化插件状态")
        }

        for plugin in plugins {
            _pluginEnabledStates[plugin.info.id] = isPluginEnabled(plugin)
        }

        if _verbose {
            _logger.info("✅ 插件状态初始化完成")
        }
    }

    /// 获取用户启用值
    private static func userEnabledValue(for plugin: any LumiPlugin.Type) -> Bool {
        _enabledOverrides[plugin.info.id] ?? plugin.policy.enabledByDefault
    }

    // MARK: - 插件列表

    /// 已注册的插件列表
    public static var registeredPlugins: [any LumiPlugin.Type] {
        plugins.filter { $0.policy.shouldRegister }
    }

    /// 启用的插件列表
    public static var enabledPlugins: [any LumiPlugin.Type] {
        registeredPlugins.filter { isPluginEnabled($0) }
    }

    /// 编辑器扩展插件列表
    public static var editorExtensionPlugins: [any LumiPlugin.Type] {
        registeredPlugins.filter { plugin in
            plugin.policy == .alwaysOn || plugin.policy == .optIn || plugin.policy == .optOut
        }
    }

    /// 启用的编辑器扩展插件 ID 集合
    public static var enabledEditorExtensionPluginIDs: Set<String> {
        Set(
            editorExtensionPlugins
                .filter { isPluginEnabled($0) }
                .map { $0.info.id }
        )
    }

    // MARK: - 回调

    /// 插件启用状态变化回调
    public static var onEnabledPluginsChanged: (() -> Void)?

    /// 插件生命周期变化回调
    public static var onPluginLifecycleChange: ((any LumiPlugin.Type, Bool) -> Void)?

    // MARK: - 聚合方法

    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        enabledPlugins.flatMap { $0.titleToolbarItems(context: context) }
    }

    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        enabledPlugins.flatMap { $0.statusBarItems(context: context) }
    }

    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        enabledPlugins.flatMap { $0.viewContainers(context: context) }
    }

    public static func menuBarContentItems(context: LumiPluginContext) -> [LumiMenuBarContentItem] {
        enabledPlugins.flatMap { $0.menuBarContentItems(context: context) }
    }

    public static func menuBarPopupItems(context: LumiPluginContext) -> [LumiMenuBarPopupItem] {
        enabledPlugins.flatMap { $0.menuBarPopupItems(context: context) }
    }

    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        enabledPlugins.flatMap { $0.llmProviders(context: context) }
    }

    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        enabledPlugins.flatMap { $0.agentTools(context: context) }
    }

    public static func subAgents(context: LumiPluginContext) -> [LumiSubAgentDefinition] {
        enabledPlugins.flatMap { $0.subAgents(context: context) }
    }

    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        enabledPlugins.flatMap { $0.sendMiddlewares(context: context) }
    }

    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        enabledPlugins.flatMap { $0.messageRenderers(context: context) }
    }

    public static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        enabledPlugins.flatMap { $0.rootOverlays(context: context) }
    }

    public static func onboardingPages(context: LumiPluginContext) -> [OnboardingPageView] {
        enabledPlugins.flatMap { plugin in
            plugin.onboardingPages(context: context).map { view in
                OnboardingPageView(order: plugin.info.order, view: view)
            }
        }
    }

    public static func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem] {
        guard context.supportsChatSection else { return [] }
        return enabledPlugins.flatMap { $0.chatSectionItems(context: context) }
    }

    public static func chatSectionRootWrapper(context: LumiPluginContext, content: AnyView) -> AnyView {
        guard context.supportsChatSection else { return content }
        return enabledPlugins.reduce(content) { wrapped, plugin in
            plugin.chatSectionRootWrapper(context: context, content: wrapped)
        }
    }

    public static func chatSectionToolbarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarItem] {
        guard context.supportsChatSection else { return [] }
        return enabledPlugins.flatMap { $0.chatSectionToolbarItems(context: context) }
    }

    public static func chatSectionToolbarBarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarBarItem] {
        guard context.supportsChatSection else { return [] }
        return enabledPlugins.flatMap { $0.chatSectionToolbarBarItems(context: context) }
    }

    public static func chatSectionHeaderItems(context: LumiPluginContext) -> [LumiChatSectionHeaderItem] {
        guard context.supportsChatSection else { return [] }
        return enabledPlugins.flatMap { $0.chatSectionHeaderItems(context: context) }
    }

    public static func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem] {
        guard context.showsPanelChrome else { return [] }
        let plugins = enabledPlugins.sorted { $0.info.order < $1.info.order }
        return plugins.flatMap { $0.panelHeaderItems(context: context) }
    }

    public static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
        guard context.showsPanelChrome else { return [] }
        let plugins = enabledPlugins.sorted { $0.info.order < $1.info.order }
        return plugins.flatMap { $0.panelBottomTabItems(context: context) }
    }

    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail else { return [] }
        let plugins = enabledPlugins.sorted { $0.info.order < $1.info.order }
        return plugins.flatMap { $0.panelRailTabItems(context: context) }
    }

    public static func llmProviderSettingsViews(context: LumiPluginContext) -> [LumiLLMProviderSettingsViewItem] {
        enabledPlugins.flatMap { $0.llmProviderSettingsViews(context: context) }
    }

    public static func logoItems(context: LumiPluginContext) -> [LogoItem] {
        enabledPlugins.flatMap { $0.logoItems(context: context) }
    }

    /// 通知所有插件 agent turn 已结束
    public static func onTurnFinished(context: LumiPluginContext, conversationID: UUID, reason: LumiTurnEndReason) async {
        for plugin in enabledPlugins {
            await plugin.onTurnFinished(context: context, conversationID: conversationID, reason: reason)
        }
    }

    /// 询问实现了 LumiToolExecutionHook 的插件，是否需要在工具执行后暂停 Agent 循环。
    ///
    /// 任意插件返回 `true` 即视为需要暂停（如 ask_user 等待用户回答）。
    /// 由 ChatService 经 App 层注入的 `toolExecutionHook` 闭包调用，
    /// 从而避免 LumiChatKit 反向依赖插件注册表。
    @MainActor
    public static func dispatchToolExecution(
        toolName: String,
        result: String,
        conversationID: UUID
    ) async -> Bool {
        for plugin in enabledPlugins {
            guard let hookPlugin = plugin as? LumiToolExecutionHook.Type else { continue }
            if await hookPlugin.handleToolResult(
                toolName: toolName,
                result: result,
                conversationID: conversationID
            ) {
                return true
            }
        }
        return false
    }
}
