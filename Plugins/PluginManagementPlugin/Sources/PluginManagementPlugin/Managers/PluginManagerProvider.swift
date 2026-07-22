import Foundation
import LumiKernel
import LumiKernel
import LumiKernel
import LumiKernel
import LumiKernel
import LumiUI
import WorkspaceStatePlugin
import SwiftUI

/// 默认插件服务实现
///
/// 负责管理所有插件的注册、启动、查询和排序。
/// 同时充当多个 Provider 服务的实现：
/// - PluginProviding: 插件管理
/// - ToolManaging: Agent Tool 收集
/// - ChatContributionProviding: Chat 贡献聚合
/// - UIThemeProviding: Theme 贡献
///
/// `LLMProviderProviding` 由独立的 `LLMProviderManagerPlugin` 实现,
/// 不再在本类中聚合。
@MainActor
public final class PluginManagerProvider: PluginProviding, ToolManaging, ChatContributionProviding, LumiChatContributionProviding, UIThemeProviding {
    public private(set) var allPlugins: [LumiPlugin] = []

    private var plugins: [String: LumiPlugin] = [:]
    private var pluginOrder: [String] = []

    /// Kernel 引用,用于插件启动和 UI 贡献注册
    weak var kernel: LumiKernel?

    private var themeRegistry: [LumiUIThemeContribution] = []

    // Agent Tool registry
    private var agentTools: [String: any LumiAgentTool] = [:]
    private var agentToolOrder: [String] = []
    private var subAgents: [String: LumiSubAgentDefinition] = [:]
    private var subAgentOrder: [String] = []

    // Send middleware registry
    private var sendMiddlewares: [String: any LumiSendMiddleware] = [:]
    private var sendMiddlewareOrder: [String] = []

    // Message renderer registry
    private var messageRenderers: [String: LumiMessageRendererItem] = [:]
    private var messageRendererOrder: [String] = []

    // Theme registry
    private var themeRegistryStorage: [LumiUIThemeContribution] = []

    // Tool execution hook registry
    private var toolExecutionHooks: [ObjectIdentifier: any LumiToolExecutionHook] = [:]

    /// 插件启用状态变化时广播 `.lumiEnabledPluginsDidChange` 通知。
    /// 供外部（如 Settings UI）在启用/禁用插件后调用。
    public func notifyEnabledPluginsDidChange() {
        NotificationCenter.default.post(name: .lumiEnabledPluginsDidChange, object: self)
    }

    public init() {}

    // MARK: - PluginProviding

    public func registerPlugin(_ plugin: LumiPlugin) throws {
        if plugins[plugin.id] == nil {
            pluginOrder.append(plugin.id)
        }
        plugins[plugin.id] = plugin
        updateSortedPlugins()
    }

    public func registerPlugins(_ plugins: [LumiPlugin]) throws {
        for plugin in plugins {
            try registerPlugin(plugin)
        }
    }

    public func bootstrapPlugins() async throws {
        guard let kernel else { return }
        for plugin in allPlugins {
            try await plugin.boot(kernel: kernel)
        }
    }

    public func plugin(id: String) -> LumiPlugin? {
        plugins[id]
    }

    public func plugin<T: LumiPlugin>(ofType type: T.Type) -> T? {
        allPlugins.first(where: { $0 is T }) as? T
    }

    /// 注册所有插件的 UI 贡献项
    public func registerPluginUIContributions(in kernel: LumiKernel) {
        self.kernel = kernel

        for plugin in allPlugins {
            guard plugin.policy.shouldRegister else { continue }
            let pluginOrder = plugin.order

            // Sub Agents
            for subAgent in plugin.subAgents(kernel: kernel) {
                addSubAgent(subAgent)
            }

            // Send Middlewares
            for middleware in plugin.sendMiddlewares(kernel: kernel) {
                registerSendMiddleware(middleware)
            }

            // Message Renderers
            for renderer in plugin.messageRenderers(kernel: kernel) {
                registerMessageRenderer(renderer)
            }

            // Menu Bar
            for content in plugin.menuBarContentItems(kernel: kernel) {
                kernel.menuBar?.registerMenuBarContent(content)
            }
            for popup in plugin.menuBarPopupItems(kernel: kernel) {
                kernel.menuBar?.registerMenuBarPopup(popup)
            }

            // Title Toolbar
            for item in plugin.titleToolbarItems(kernel: kernel) {
                kernel.toolbarProvider?.registerTitleToolbarItem(item)
            }

            // Panel
            for item in plugin.panelHeaderItems(kernel: kernel) {
                kernel.panel?.registerPanelHeaderItem(item)
            }
            for item in plugin.panelBottomTabItems(kernel: kernel) {
                var tabItem = PanelBottomTabItem(
                    id: item.id,
                    title: item.title,
                    systemImage: item.systemImage,
                    content: item.makeView
                )
                tabItem.order = pluginOrder
                kernel.panel?.registerPanelBottomTabItem(tabItem)
            }
            for item in plugin.panelRailTabItems(kernel: kernel) {
                var railItem = PanelRailTabItem(
                    id: item.id,
                    title: item.title,
                    systemImage: item.systemImage,
                    content: item.makeView
                )
                railItem.order = pluginOrder
                kernel.panel?.registerPanelRailTabItem(railItem)
            }

            // View Containers
            for container in plugin.viewContainers(kernel: kernel) {
                let viewContainer: ViewContainerItem
                if let makeView = container.makeView {
                    viewContainer = ViewContainerItem(
                        id: container.id,
                        title: container.title,
                        systemImage: container.systemImage,
                        content: makeView
                    )
                } else {
                    viewContainer = ViewContainerItem(
                        id: container.id,
                        title: container.title,
                        systemImage: container.systemImage
                    )
                }
                var containerWithOrder = viewContainer
                containerWithOrder.order = pluginOrder
                kernel.viewContainer?.register(containerWithOrder)
            }

            // Chat Section
            for item in plugin.chatSectionItems(kernel: kernel) {
                var chatItem = ChatSectionItem(
                    id: item.id,
                    placement: item.placement,
                    fillsRemainingHeight: item.fillsRemainingHeight,
                    showsTrailingDivider: item.showsTrailingDivider,
                    content: item.makeView
                )
                chatItem.order = pluginOrder
                kernel.chatSection?.registerChatSectionItem(chatItem)
            }
            for item in plugin.chatSectionToolbarItems(kernel: kernel) {
                var toolbarItem = ChatSectionToolbarItem(
                    id: item.id,
                    placement: item.placement,
                    content: item.makeView
                )
                toolbarItem.order = pluginOrder
                kernel.chatSection?.registerChatSectionToolbarItem(toolbarItem)
            }
            for item in plugin.chatSectionToolbarBarItems(kernel: kernel) {
                var barItem = ChatSectionToolbarBarItem(
                    id: item.id,
                    content: item.makeView
                )
                barItem.order = pluginOrder
                kernel.chatSection?.registerChatSectionToolbarBarItem(barItem)
            }
            for item in plugin.chatSectionHeaderItems(kernel: kernel) {
                var headerItem = ChatSectionHeaderItem(
                    id: item.id,
                    content: item.makeView
                )
                headerItem.order = pluginOrder
                kernel.chatSection?.registerChatSectionHeaderItem(headerItem)
            }
            for item in plugin.chatSectionActionBarItems(kernel: kernel) {
                var actionBarItem = ChatSectionActionBarItem(
                    id: item.id,
                    content: item.makeView
                )
                actionBarItem.order = pluginOrder
                kernel.chatSection?.registerChatSectionActionBarItem(actionBarItem)
            }

            // Status Bar
            for item in plugin.statusBarItems(kernel: kernel) {
                kernel.statusBar?.registerStatusBarItem(item)
            }

            // Settings
            for item in plugin.settingsTabItems(kernel: kernel) {
                kernel.settings?.registerSettingsTabItem(item)
            }
            for item in plugin.llmProviderSettingsItems(kernel: kernel) {
                kernel.settings?.registerLLMProviderSettingsItem(item)
            }

            // Logo
            for item in plugin.logoItems(kernel: kernel) {
                var logoItem: LogoItem
                if let makeOverlay = item.makeOverlay {
                    logoItem = LogoItem(
                        id: item.id,
                        makeView: item.makeView,
                        makeOverlay: makeOverlay
                    )
                } else {
                    logoItem = LogoItem(
                        id: item.id,
                        makeView: item.makeView
                    )
                }
                logoItem.order = pluginOrder
                kernel.logo?.registerLogoItem(logoItem)
            }

            // Onboarding
            for page in plugin.onboardingPages(kernel: kernel) {
                var pageItem = OnboardingPageItem(
                    id: page.id,
                    content: page.makeView
                )
                pageItem.order = pluginOrder
                kernel.onboarding?.registerOnboardingPage(pageItem)
            }

            // Theme contributions
            if let themeProvider = plugin as? any UIThemeProviding {
                for theme in themeProvider.themeContributions() {
                    themeRegistryStorage.append(theme)
                }
            }
        }

        // Sync layout active section with registered view containers.
        let containers = kernel.viewContainer?.allViewContainers ?? []
        if let first = containers.first,
           let layoutService = kernel.layout,
           layoutService.state.activeSectionID.isEmpty {
            layoutService.updateLayout { state in
                state.activeSectionID = first.id
                state.activeSectionTitle = ""
            }
        }

        // 应用每个插件声明的工作区可见性偏好
        for plugin in allPlugins {
            guard plugin.policy.shouldRegister else { continue }
            let visibility = plugin.workspaceVisibility(kernel: kernel)
            kernel.workspaceState?.applyVisibility(
                rail: visibility.rail,
                chat: visibility.chat,
                content: visibility.content,
                activityBar: visibility.activityBar,
                panel: visibility.panel
            )
        }

        // 注册容器激活观察器：每个插件在容器激活时收到回调
        if let workspacePlugin = allPlugins.first(where: { $0 is WorkspaceStatePlugin }) as? WorkspaceStatePlugin,
           let stateProvider = workspacePlugin.instance {
            for plugin in allPlugins {
                guard plugin.policy.shouldRegister else { continue }
                let pluginID = plugin.id
                stateProvider.addContainerObserver { containerID in
                    plugin.onContainerActivated(kernel: kernel, containerID: containerID)
                    _ = pluginID
                }
            }
        }
    }

    private func updateSortedPlugins() {
        allPlugins = pluginOrder.compactMap { plugins[$0] }
            .sorted { $0.order < $1.order }
    }

    // MARK: - ChatContributionProviding (LLM Provider passthrough)

    /// 旧 `ChatContributionProviding` 协议要求 `allLLMProviders()`。
    /// LLM Provider 收集已搬到 `LLMProviderManagerPlugin`,本方法把
    /// 收集结果转调过去;调用方拿不到数据时返回空数组。
    public func allLLMProviders() -> [any LumiLLMProvider] {
        kernel?.llmProvider?.allLLMProviders() ?? []
    }

    // MARK: - ToolManaging

    public func allAgentTools() -> [any LumiAgentTool] {
        agentToolOrder.compactMap { agentTools[$0] }
    }

    public func add(_ tool: any LumiAgentTool) {
        let id = tool.name
        if agentTools[id] == nil {
            agentToolOrder.append(id)
        }
        agentTools[id] = tool
    }

    public func remove(id: String) {
        agentTools.removeValue(forKey: id)
        agentToolOrder.removeAll { $0 == id }
    }

    public func allSubAgents() -> [LumiSubAgentDefinition] {
        subAgentOrder.compactMap { subAgents[$0] }
    }

    public func addSubAgent(_ subAgent: LumiSubAgentDefinition) {
        if subAgents[subAgent.id] == nil {
            subAgentOrder.append(subAgent.id)
        }
        subAgents[subAgent.id] = subAgent
    }

    // MARK: - ToolManaging Execution

    public func tool(named name: String) -> (any LumiAgentTool)? {
        kernel?.toolManager?.tool(named: name)
    }

    public func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult {
        await kernel?.toolManager?.execute(toolCall, conversationID: conversationID) ?? LumiToolResult(content: "Tool service unavailable", isError: true)
    }

    // MARK: - ChatContributionProviding

    public func allSendMiddlewares() -> [any LumiSendMiddleware] {
        sendMiddlewareOrder.compactMap { sendMiddlewares[$0] }
    }

    public func allMessageRenderers() -> [LumiMessageRendererItem] {
        messageRendererOrder.compactMap { messageRenderers[$0] }
    }

    public func dispatchTurnFinished(conversationID: UUID, reason: LumiTurnEndReason) async {
        guard let kernel else { return }
        for plugin in allPlugins {
            await plugin.onTurnFinished(kernel: kernel, conversationID: conversationID, reason: reason)
        }
    }

    // MARK: - LumiChatContributionProviding (新 API)
    //
    // 适配 `LumiCoreChat.ChatService.applyPluginContributions(from:)` 的调用形式。
    // 老 API（ChatContributionProviding.allXxx()）保留以便旧代码继续工作。

    public func llmProviders(lumiCore: any LumiCoreProviding) -> [any LumiLLMProvider] {
        // LLM Provider 收集已由 LLMProviderManagerPlugin 负责。
        // 本方法保留以便 `LumiCoreChat.ChatService.applyPluginContributions`
        // 仍然能调用,但目前没有 LLM Provider 插件接入 App,返回空数组。
        []
    }

    public func sendMiddlewares(lumiCore: any LumiCoreProviding) -> [any LumiSendMiddleware] {
        allSendMiddlewares()
    }

    public func messageRenderers(lumiCore: any LumiCoreProviding) -> [LumiMessageRendererItem] {
        allMessageRenderers()
    }

    public func onTurnFinished(
        lumiCore: any LumiCoreProviding,
        conversationID: UUID,
        reason: LumiTurnEndReason
    ) async {
        await dispatchTurnFinished(conversationID: conversationID, reason: reason)
    }

    // MARK: - Send Middleware Registry

    public func registerSendMiddleware(_ middleware: any LumiSendMiddleware, id: String? = nil) {
        let key = id ?? String(describing: type(of: middleware))
        if sendMiddlewares[key] == nil {
            sendMiddlewareOrder.append(key)
        }
        sendMiddlewares[key] = middleware
    }

    public func unregisterSendMiddleware(id: String) {
        sendMiddlewares.removeValue(forKey: id)
        sendMiddlewareOrder.removeAll { $0 == id }
    }

    public func registerMessageRenderer(_ renderer: LumiMessageRendererItem) {
        if messageRenderers[renderer.id] == nil {
            messageRendererOrder.append(renderer.id)
        }
        messageRenderers[renderer.id] = renderer
    }

    // MARK: - UIThemeProviding

    public func themeContributions() -> [LumiUIThemeContribution] {
        themeRegistryStorage
    }

    // MARK: - Tool Execution Hook

    public func registerToolExecutionHook(_ hook: any LumiToolExecutionHook) {
        toolExecutionHooks[ObjectIdentifier(type(of: hook))] = hook
    }

    public func dispatchToolExecution(toolName: String, result: String, conversationID: UUID) async -> Bool {
        for hook in toolExecutionHooks.values {
            if await hook.handleToolResult(toolName: toolName, result: result, conversationID: conversationID) {
                return true
            }
        }
        return false
    }

    // MARK: - Plugin Management

    /// 检测所有已注册插件是否有 ID 重复
    public func detectDuplicatePluginIDs() -> [(id: String, plugins: [LumiPlugin])] {
        var idToPlugins: [String: [LumiPlugin]] = [:]
        for plugin in allPlugins {
            idToPlugins[plugin.id, default: []].append(plugin)
        }
        return idToPlugins
            .filter { $0.value.count > 1 }
            .map { (id: $0.key, plugins: $0.value) }
            .sorted { $0.id < $1.id }
    }
}
