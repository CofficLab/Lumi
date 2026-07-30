import Foundation
import SwiftUI

/// 内置插件管理器
///
/// 负责管理所有插件的注册、启动、查询和排序。
@MainActor
public final class BuiltinPluginManager: ObservableObject {
    public private(set) var allPlugins: [LumiPlugin] = []

    private var plugins: [String: LumiPlugin] = [:]
    private var pluginOrder: [String] = []

    /// Kernel 引用
    weak var kernel: LumiKernelContainer?

    // Message renderer registry
    private var messageRenderers: [String: LumiMessageRendererItem] = [:]
    private var messageRendererOrder: [String] = []

    // 插件启用状态覆盖只保留在内存中；磁盘持久化由 PluginManagerPlugin 负责。
    private var enabledOverrides: [String: Bool] = [:]
    private weak var enabledStatePersistence: (any PluginEnabledStatePersistence)?

    /// 插件启用状态变化时广播通知
    public func notifyEnabledPluginsDidChange() {
        kernel?.eventManager.postEnabledPluginsDidChange(object: self)
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

    /// 注入由 PluginManagerPlugin 提供的持久化实现，并把已保存状态载入内存。
    /// 必须在可配置插件启动前调用。
    public func installEnabledStatePersistence(_ persistence: any PluginEnabledStatePersistence) {
        enabledStatePersistence = persistence
        enabledOverrides = persistence.loadPluginEnabledOverrides()
    }

    public func onBoot(kernel: LumiKernel) async throws {
        // 核心插件先启动：StoragePlugin 会先提供插件数据目录，随后
        // PluginManagerPlugin 才能加载启用状态。
        for plugin in allPlugins where plugin.policy == .alwaysOn {
            try await plugin.onBoot(kernel: kernel)
        }

        // 可配置插件必须等持久化状态注入后再启动，避免先按默认值启动。
        for plugin in allPlugins where plugin.policy != .alwaysOn {
            guard effectiveEnabled(for: plugin) else { continue }
            try await plugin.onBoot(kernel: kernel)
        }
    }

    public func onReady(kernel: LumiKernel) async throws {
        for plugin in allPlugins {
            guard effectiveEnabled(for: plugin) else { continue }
            try await plugin.onReady(kernel: kernel)
        }

        // 注册容器激活观察者，当容器切换时通知所有插件
        kernel.layoutManager?.addContainerObserver { [weak self] containerID in
            guard let self else { return }
            Task { @MainActor in
                self.onContainerActivated(kernel: kernel, containerID: containerID)
            }
        }
    }

    public func onContainerActivated(kernel: LumiKernel, containerID: String) {
        // 可见性已在 LayoutState.activateContainer() 中自动应用
        // 此处仅广播给插件（用于非可见性的副作用）
        for plugin in allPlugins {
            guard effectiveEnabled(for: plugin) else { continue }
            plugin.onContainerActivated(kernel: kernel, containerID: containerID)
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

        // 全量重建:先清空各 Provider 服务与 manager 自身的内部 registry,
        // 再按"有效启用"状态重新注册。这样禁用某插件时,其贡献会即时撤回。
        // 首次启动时各 registry 为空,清空为 no-op,不影响行为。
        clearInternalContributions()
        kernel.settings?.clearAllContributions()
        kernel.uiManager?.clearAllContributions()
        kernel.logo?.clearAllContributions()
        // onboarding 服务当前未注册(kernel.onboarding == nil),无需处理。

        for plugin in allPlugins {
            guard effectiveEnabled(for: plugin) else { continue }
            let pluginOrder = plugin.order

            // Send Middlewares: now handled via LumiPlugin.willSendToLLM hook in AgentTurnRunner

            // Message Renderers
            for renderer in plugin.messageRenderers(kernel: kernel) {
                registerMessageRenderer(renderer)
                kernel.messageRendererManager?.registerMessageRenderer(renderer)
            }

            // Menu Bar
            for content in plugin.menuBarContentItems(kernel: kernel) {
                kernel.uiManager?.registerMenuBarContent(content)
            }
            for popup in plugin.menuBarPopupItems(kernel: kernel) {
                kernel.uiManager?.registerMenuBarPopup(popup)
            }

            // Title Toolbar
            for item in plugin.titleToolbarItems(kernel: kernel) {
                kernel.uiManager?.registerTitleToolbarItem(item)
            }

            // Panel
            for item in plugin.panelHeaderItems(kernel: kernel) {
                kernel.uiManager?.registerPanelHeaderItem(item)
            }
            for item in plugin.panelBottomTabItems(kernel: kernel) {
                var tabItem = PanelBottomTabItem(
                    id: item.id,
                    title: item.title,
                    systemImage: item.systemImage,
                    content: item.makeView
                )
                tabItem.order = pluginOrder
                kernel.uiManager?.registerPanelBottomTabItem(tabItem)
            }
            for item in plugin.panelRailTabItems(kernel: kernel) {
                var railItem = PanelRailTabItem(
                    id: item.id,
                    title: item.title,
                    systemImage: item.systemImage,
                    content: item.makeView
                )
                railItem.order = pluginOrder
                kernel.uiManager?.registerPanelRailTabItem(railItem)
            }

            // View Containers
            for container in plugin.viewContainers(kernel: kernel) {
                let viewContainer: ViewContainerItem
                if let makeView = container.makeView {
                    viewContainer = ViewContainerItem(
                        id: container.id,
                        title: container.title,
                        systemImage: container.systemImage,
                        isRailVisible: container.isRailVisible,
                        isChatVisible: container.isChatVisible,
                        isContentVisible: container.isContentVisible,
                        isPanelVisible: container.isPanelVisible,
                        isPanelHeaderVisible: container.isPanelHeaderVisible,
                        isPanelBottomVisible: container.isPanelBottomVisible,
                        content: makeView
                    )
                } else {
                    viewContainer = ViewContainerItem(
                        id: container.id,
                        title: container.title,
                        systemImage: container.systemImage,
                        isRailVisible: container.isRailVisible,
                        isChatVisible: container.isChatVisible,
                        isContentVisible: container.isContentVisible,
                        isPanelVisible: container.isPanelVisible,
                        isPanelHeaderVisible: container.isPanelHeaderVisible,
                        isPanelBottomVisible: container.isPanelBottomVisible
                    )
                }
                var containerWithOrder = viewContainer
                containerWithOrder.order = pluginOrder
                kernel.layoutManager?.registerViewContainer(containerWithOrder)
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
                kernel.uiManager?.registerChatSectionItem(chatItem)
            }
            for item in plugin.chatSectionToolbarItems(kernel: kernel) {
                var toolbarItem = ChatSectionToolbarItem(
                    id: item.id,
                    placement: item.placement,
                    content: item.makeView
                )
                toolbarItem.order = pluginOrder
                kernel.uiManager?.registerChatSectionToolbarItem(toolbarItem)
            }
            for item in plugin.chatSectionToolbarBarItems(kernel: kernel) {
                var barItem = ChatSectionToolbarBarItem(
                    id: item.id,
                    content: item.makeView
                )
                barItem.order = pluginOrder
                kernel.uiManager?.registerChatSectionToolbarBarItem(barItem)
            }
            for item in plugin.chatSectionHeaderItems(kernel: kernel) {
                var headerItem = ChatSectionHeaderItem(
                    id: item.id,
                    content: item.makeView
                )
                headerItem.order = pluginOrder
                kernel.uiManager?.registerChatSectionHeaderItem(headerItem)
            }
            for item in plugin.chatSectionActionBarItems(kernel: kernel) {
                var actionBarItem = ChatSectionActionBarItem(
                    id: item.id,
                    placement: item.placement,
                    content: item.makeView
                )
                actionBarItem.order = pluginOrder
                kernel.uiManager?.registerChatSectionActionBarItem(actionBarItem)
            }

            // Status Bar
            for item in plugin.statusBarItems(kernel: kernel) {
                kernel.uiManager?.registerStatusBarItem(item)
            }

            // Settings
            for item in plugin.settingsTabItems(kernel: kernel) {
                kernel.settings?.registerSettingsTabItem(item)
            }
            for item in plugin.llmProviderSettingsItems(kernel: kernel) {
                kernel.settings?.registerLLMProviderSettingsItem(item)
            }

            // Root Overlays
            for item in plugin.rootOverlays(kernel: kernel) {
                var overlayItem = item
                overlayItem.order = pluginOrder
                kernel.uiManager?.registerRootOverlayItem(overlayItem)
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
        }

        // Sync layout active section with registered view containers.
        let containers = kernel.layoutManager?.allViewContainers ?? []
        if let first = containers.first,
           let layoutService = kernel.layoutManager,
           layoutService.layoutState.activeViewContainerID == nil {
            layoutService.layoutState.activeViewContainerID = first.id
        }

        // 容器注册完毕后，回填当前激活容器的可见性声明。
        // 持久化恢复（`LayoutPersistenceCoordinator.restore()`）发生在 `onReady` 阶段，
        // 此时容器还未注册，只能直接给 `activeViewContainerID` 赋值，绕过了
        // `activateContainer` → `onContainerActivated` 的可见性应用路径。
        // 因此启动/重建完成后必须在此处补一次 apply，否则 rail/chat 仍按默认值显示。
        if let containerID = kernel.layoutManager?.layoutState.activeViewContainerID,
           let container = kernel.layoutManager?.viewContainer(id: containerID) {
            kernel.layoutManager?.applyVisibility(
                rail: container.isRailVisible,
                chat: container.isChatVisible,
                content: container.isContentVisible,
                panel: container.isPanelVisible
            )
        }

    }

    /// 收集所有插件贡献的 LLM Provider,并注册到内核的 `LLMProviderManaging` 服务。
    ///
    /// 调用时机:在 `LumiKernel.startup()` 的 `onReady` 之后。每个 LLM Provider 插件
    /// (Anthropic、OpenAI、…)只需实现 `LumiPlugin.llmProviders(kernel:)` 返回其实例,
    /// 无需再在 `onBoot/onReady` 里主动调用 `kernel.llmProvider?.registerLLMProvider(...)`。
    ///
    /// `LLMProviderManagerPlugin` 必须已经注册(其 `order = 10`,在内核启动时最先
    /// 完成),因此这里 `kernel.llmProvider` 一定可用;若不可用则抛错,不再静默。
    ///
    /// - Throws:
    ///   - `LumiKernelError.serviceNotAvailable("LLMProvider")` 当 manager 服务
    ///     未注册时。
    ///   - `LumiKernelError.llmProviderRegistrationFailed` 当某个 provider 的
    ///     `info.id` 为空时。
    public func registerLLMProviders(in kernel: LumiKernel) throws {
        self.kernel = kernel

        guard let manager = kernel.llmProvider else {
            throw LumiKernelError.serviceNotAvailable(service: "LLMProvider")
        }

        // 先按 order 收集所有已启用插件的 LLM Provider,保持插件顺序,
        // 再一次性批量注册,避免逐个调用的日志噪声和潜在的多次副作用。
        var collected: [any LumiLLMProvider] = []
        for plugin in allPlugins {
            guard effectiveEnabled(for: plugin) else { continue }
            collected.append(contentsOf: plugin.llmProviders(kernel: kernel))
        }
        try manager.registerLLMProviders(collected)
    }

    /// 收集所有插件贡献的 Agent 工具,并注册到内核的 `ToolManaging` 服务。
    ///
    /// 调用时机:在 `LumiKernel.startup()` 的 `onReady` 之后,且 `registerLLMProviders` 之后。
    /// 每个需要贡献工具的插件只需实现 `LumiPlugin.agentTools(kernel:)` 返回其实例,
    /// 无需再在 `onBoot/onReady` 里主动调用 `kernel.toolManager?.add(...)`。
    ///
    /// `ToolManagerPlugin` 必须已经注册(其 `order = 30`),因此这里 `kernel.toolManager` 一定可用;
    /// 若不可用则抛错,不再静默。
    ///
    /// - Throws:
    ///   - `LumiKernelError.serviceNotAvailable("AgentTool")` 当 manager 服务未注册时。
    public func registerAgentTools(in kernel: LumiKernel) throws {
        self.kernel = kernel

        guard let manager = kernel.toolManager else {
            throw LumiKernelError.serviceNotAvailable(service: "AgentTool")
        }

        manager.removeAll()
        manager.removeAllSubAgents()

        // Build the ordinary tool set first. Sub-agents receive this snapshot so they
        // can use project tools without seeing the unified delegate tool.
        for plugin in allPlugins {
            guard effectiveEnabled(for: plugin) else { continue }
            let tools = plugin.agentTools(kernel: kernel)
            for tool in tools {
                manager.add(tool, pluginID: plugin.id)
            }
        }

        let availableTools = manager.allAgentTools()
        let providerResolver: @MainActor @Sendable (String) -> (any LumiLLMProvider)? = { [weak kernel] id in
            kernel?.llmProvider?.llmProvider(id: id)
        }

        for plugin in allPlugins {
            guard effectiveEnabled(for: plugin) else { continue }
            for definition in plugin.subAgents(kernel: kernel) {
                manager.addSubAgent(definition)
            }
        }
        let subAgents = manager.allSubAgents()
        if !subAgents.isEmpty {
            manager.add(
                SubAgentRouterTool(
                    definitions: subAgents,
                    providerResolver: providerResolver,
                    availableTools: availableTools,
                    executionToolService: manager
                ),
                pluginID: "Sub Agents"
            )
        }
    }

    /// 收集所有插件贡献的编辑器运行时插件,并注册到内核的 `EditorProviding` 服务。
    ///
    /// 调用时机:在 `LumiKernel.startup()` 的 `onReady` 之后。每个语言/语法插件
    /// 只需实现 `LumiPlugin.editorPlugins(kernel:)` 返回面向 `LumiKernel` 协议的
    /// `EditorPlugin` 实例,无需直接依赖 `EditorService` 或接触具体注册表。
    public func registerEditorPlugins(in kernel: LumiKernel) {
        self.kernel = kernel
        kernel.editorProvider?.replaceEditorPlugins(collectEditorPlugins(in: kernel))
    }

    /// 全量重建所有插件贡献(Agent Tools + UI + LLM Provider + Editor Plugins)。
    ///
    /// 在插件启用/禁用后由宿主(`LumiFactory.subscribeToPluginChanges`)调用,
    /// 使被禁用插件的贡献即时撤回、被启用插件的贡献即时加入。
    ///
    /// - Agent Tools:先清空 ToolManager 再按有效启用状态重新注册。
    /// - UI 贡献:先 clear 各 Provider 再按有效启用状态重新注册。
    /// - LLM Provider:采用 diff 策略——注销已注册但不再属于有效集合的 provider,
    ///   再幂等注册有效集合,以保留用户当前选中的 provider/model(若仍可用)。
    public func rebuildAllContributions(in kernel: LumiKernel) {
        self.kernel = kernel

        // 1. Agent Tools 重建 — 必须在 UI 贡献重建之前,
        //    确保 settingsTabItems 创建视图时能读取到已注册的工具列表。
        if let toolManager = kernel.toolManager {
            toolManager.removeAll()
            toolManager.removeAllSubAgents()
            for plugin in allPlugins {
                guard effectiveEnabled(for: plugin) else { continue }
                let tools = plugin.agentTools(kernel: kernel)
                for tool in tools {
                    toolManager.add(tool, pluginID: plugin.id)
                }
            }
            let availableTools = toolManager.allAgentTools()
            let providerResolver: @MainActor @Sendable (String) -> (any LumiLLMProvider)? = { [weak kernel] id in
                kernel?.llmProvider?.llmProvider(id: id)
            }
            for plugin in allPlugins {
                guard effectiveEnabled(for: plugin) else { continue }
                for definition in plugin.subAgents(kernel: kernel) {
                    toolManager.addSubAgent(definition)
                }
            }
            let subAgents = toolManager.allSubAgents()
            if !subAgents.isEmpty {
                toolManager.add(
                    SubAgentRouterTool(
                        definitions: subAgents,
                        providerResolver: providerResolver,
                        availableTools: availableTools,
                        executionToolService: toolManager
                    ),
                    pluginID: "Sub Agents"
                )
            }
        }

        // 2. UI 贡献重建
        registerPluginUIContributions(in: kernel)

        // 3. Editor Plugins 重建
        //    必须通过 replace 入口撤回已禁用插件的语言/语法/高亮贡献,再回放当前有效集合。
        registerEditorPlugins(in: kernel)

        // 4. LLM Provider 重建(diff)
        guard let manager = kernel.llmProvider else { return }
        let effectiveIDs = Set(
            allPlugins
                .filter { effectiveEnabled(for: $0) }
                .flatMap { $0.llmProviders(kernel: kernel).map { type(of: $0).info.id } }
        )
        for registered in manager.allLLMProviders() {
            let id = type(of: registered).info.id
            if !effectiveIDs.contains(id) {
                manager.unregisterLLMProvider(id: id)
            }
        }
        let collected = allPlugins
            .filter { effectiveEnabled(for: $0) }
            .flatMap { $0.llmProviders(kernel: kernel) }
        try? manager.registerLLMProviders(collected)
    }

    private func collectEditorPlugins(in kernel: LumiKernel) -> [any EditorPlugin] {
        allPlugins
            .filter { effectiveEnabled(for: $0) }
            .flatMap { $0.editorPlugins(kernel: kernel) }
            .sorted { lhs, rhs in
                if lhs.order != rhs.order {
                    return lhs.order < rhs.order
                }
                return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
            }
    }

    private func updateSortedPlugins() {
        allPlugins = pluginOrder.compactMap { plugins[$0] }
            .sorted { $0.order < $1.order }
    }

    // MARK: - Send Middleware Registry (removed: now handled via LumiPlugin.willSendToLLM hook)

    public func registerMessageRenderer(_ renderer: LumiMessageRendererItem) {
        if messageRenderers[renderer.id] == nil {
            messageRendererOrder.append(renderer.id)
        }
        messageRenderers[renderer.id] = renderer
    }

    /// 清空 manager 自身维护的内部贡献 registry(供全量重建使用)。
    ///
    /// 与各 Provider 服务的 `clearAllContributions()` 配合,在
    /// `registerPluginUIContributions(in:)` 开头调用,使禁用插件的贡献即时撤回。
    public func clearInternalContributions() {
        messageRenderers.removeAll()
        messageRendererOrder.removeAll()
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

    // MARK: - Plugin Enabled State

    /// 解析某个插件的"有效启用状态"。
    ///
    /// - `alwaysOn`:始终启用(忽略用户覆盖)。
    /// - `disabled`:始终禁用(忽略用户覆盖)。
    /// - `optOut` / `optIn`:读取用户覆盖,缺省时回落到 `policy.enabledByDefault`。
    public func effectiveEnabled(for plugin: LumiPlugin) -> Bool {
        switch plugin.policy {
        case .alwaysOn:
            return true
        case .disabled:
            return false
        case .optOut, .optIn:
            if let override = enabledOverrides[plugin.id] {
                return override
            }
            return plugin.policy.enabledByDefault
        }
    }

    /// 按 ID 查询插件是否处于有效启用状态。
    public func isPluginEnabled(id: String) -> Bool {
        guard let plugin = plugin(id: id) else { return false }
        return effectiveEnabled(for: plugin)
    }

    /// 当前处于有效启用状态的插件数量(用于统计展示)。
    public var enabledPluginCount: Int {
        allPlugins.reduce(0) { $0 + (effectiveEnabled(for: $1) ? 1 : 0) }
    }

    /// 设置某个插件的启用状态(用户操作)。
    ///
    /// 仅对可配置插件(`policy.isConfigurable`)生效;`alwaysOn` / `disabled` 为 no-op。
    /// 更新后持久化覆盖值、驱动 SwiftUI 重渲染并广播 `.lumiEnabledPluginsDidChange`,
    /// 从而触发 `LumiFactory` 重新注册 UI 贡献(禁用的插件贡献即时撤回)。
    public func setPlugin(id: String, enabled: Bool) {
        guard let plugin = plugin(id: id) else { return }
        guard plugin.policy.isConfigurable else { return }
        let current = effectiveEnabled(for: plugin)
        guard current != enabled else { return }

        enabledOverrides[id] = enabled
        enabledStatePersistence?.savePluginEnabledOverride(enabled, for: id)
        objectWillChange.send()
        notifyEnabledPluginsDidChange()
    }

    /// 清除某个插件的用户覆盖(回落到 policy 默认)。
    public func resetPlugin(id: String) {
        guard let plugin = plugin(id: id) else { return }
        guard plugin.policy.isConfigurable else { return }
        enabledOverrides.removeValue(forKey: id)
        enabledStatePersistence?.clearPluginEnabledOverride(for: id)
        objectWillChange.send()
        notifyEnabledPluginsDidChange()
    }
}
