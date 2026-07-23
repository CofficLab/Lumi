import Foundation
import SwiftUI

/// 内置插件管理器
///
/// 负责管理所有插件的注册、启动、查询和排序。
/// 同时充当多个 Provider 服务的实现：
/// - ToolManaging: Agent Tool 收集
/// - UIThemeProviding: Theme 贡献
@MainActor
public final class BuiltinPluginManager: ObservableObject, PluginRegistry, ToolManaging, UIThemeProviding {
    public private(set) var allPlugins: [LumiPlugin] = []

    private var plugins: [String: LumiPlugin] = [:]
    private var pluginOrder: [String] = []

    /// Kernel 引用
    weak var kernel: LumiKernelContainer?

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

    /// 插件启用状态变化时广播通知
    public func notifyEnabledPluginsDidChange() {
        NotificationCenter.default.post(name: .lumiEnabledPluginsDidChange, object: self)
    }

    init() {}

    // MARK: - PluginManaging

    public func initializePlugins(_ plugins: [LumiPlugin], kernel: LumiKernel) async throws {
        self.kernel = kernel

        // 按 order 排序
        let sortedPlugins = plugins.sorted { $0.order < $1.order }

        // 存储所有插件实例
        for plugin in sortedPlugins {
            if self.plugins[plugin.id] == nil {
                pluginOrder.append(plugin.id)
            }
            self.plugins[plugin.id] = plugin
        }
        updateSortedPlugins()
    }

    public func onBoot(kernel: LumiKernel) async throws {
        for plugin in allPlugins {
            guard plugin.policy.shouldRegister else { continue }
            try await plugin.onBoot(kernel: kernel)
        }
    }

    public func onReady(kernel: LumiKernel) async throws {
        for plugin in allPlugins {
            guard plugin.policy.shouldRegister else { continue }
            try await plugin.onReady(kernel: kernel)
        }
    }

    public func plugin(id: String) -> LumiPlugin? {
        plugins[id]
    }

    public func plugin<T: LumiPlugin>(ofType type: T.Type) -> T? {
        allPlugins.first(where: { $0 is T }) as? T
    }

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
    }

    private func updateSortedPlugins() {
        allPlugins = pluginOrder.compactMap { plugins[$0] }
            .sorted { $0.order < $1.order }
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

    // MARK: - Plugin Management

    /// 检测所有已注册插件是否有 ID 重复
    public func detectDuplicatePluginIDs() -> [(id: String, plugins: [LumiPlugin])] {
        var idToPlugin: [String: [LumiPlugin]] = [:]
        for plugin in allPlugins {
            idToPlugin[plugin.id, default: []].append(plugin)
        }
        return idToPlugin
            .filter { $0.value.count > 1 }
            .map { (id: $0.key, plugins: $0.value) }
            .sorted { $0.id < $1.id }
    }
}
