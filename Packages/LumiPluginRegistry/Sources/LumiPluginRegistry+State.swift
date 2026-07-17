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

    /// 最近一次 `agentTools(context:)` 收集过程中累积的插件失败列表。
    ///
    /// 反映"当前启用集"的最新失败快照——每次聚合都会整体覆盖。
    /// 由 `AgentToolComponent` 经 `AgentToolProviding.lastAgentToolFailures()` 读取。
    private static var _agentToolFailures: [LumiPluginContributionFailure] = []

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
        NotificationCenter.postLumiEnabledPluginsDidChange()

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

    /// 最近一次工具收集产生的插件失败快照（只读访问）。
    public static var agentToolFailures: [LumiPluginContributionFailure] {
        _agentToolFailures
    }

    /// 聚合所有启用插件的 `agentTools`。
    ///
    /// 单个插件抛错时**不影响其他插件**：异常被捕获并包装成
    /// `LumiPluginContributionFailure` 累积到 `_agentToolFailures`，成功插件的工具
    /// 照常返回。对外签名保持非 throws——所有调用点（boot 校验、运行期注册、
    /// `AgentToolProviding`）都无需改动。真正的硬错误（工具名重复）由
    /// `ToolService.registerTools` 在更上层抛出，与这里无关。
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        var tools: [any LumiAgentTool] = []
        var failures: [LumiPluginContributionFailure] = []

        for plugin in enabledPlugins {
            do {
                tools.append(contentsOf: try plugin.agentTools(context: context))
            } catch {
                failures.append(LumiPluginContributionFailure(
                    pluginID: plugin.info.id,
                    pluginDisplayName: plugin.info.displayName,
                    contribution: "agentTools",
                    errorDescription: error.localizedDescription
                ))
                _logger.error("插件 \(plugin.info.id) agentTools 失败：\(error.localizedDescription)")
            }
        }

        // 整体覆盖：反映"当前启用集"的最新失败快照（禁用插件后旧失败应消失）。
        _agentToolFailures = failures
        return tools
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

// MARK: - NotificationCenter 扩展

/// 插件启用状态变化的广播机制。
///
/// 与 `LumiProviderState` 等内核状态对象一致，采用 `NotificationCenter` 作为
/// 多订阅者广播：任何关心的服务（主题 / 菜单栏 / 编辑器扩展 / 工具贡献等）
/// 都可以在自己的 init 里订阅 `Notification.Name.lumiEnabledPluginsDidChange`，
/// 无需中心化的 fan-out 协调器。
///
/// 旧的 `onEnabledPluginsChanged` 单一闭包槽予以保留（向后兼容），新的
/// Notification 与它在 `setPlugin` 中**同步双发**。
public extension Notification.Name {
    /// 插件启用集合发生变化时广播。订阅者用 `.onReceive` 或
    /// `NotificationCenter.default.addObserver(forName: .lumiEnabledPluginsDidChange, ...)`。
    static let lumiEnabledPluginsDidChange = Notification.Name("LumiPluginRegistry.EnabledPluginsDidChange")
}

public extension NotificationCenter {
    /// 插件启用集合发生变化时 post（在 `setPlugin` 中与旧闭包槽同步双发）。
    static func postLumiEnabledPluginsDidChange() {
        NotificationCenter.default.post(name: .lumiEnabledPluginsDidChange, object: nil)
    }

    /// 订阅插件启用集合变化。返回 observer token，可传给 `removeObserver`。
    ///
    /// block 声明为 `@MainActor`：因为 observer 注册时传了 `queue: .main`，回调必然在
    /// 主线程发生，订阅方可以直接调用 `@MainActor` 方法而无需额外 `Task { @MainActor in }` 包裹。
    @discardableResult
    func onLumiEnabledPluginsDidChange(using block: @escaping @MainActor @Sendable () -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .lumiEnabledPluginsDidChange,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { block() }
        }
    }
}
