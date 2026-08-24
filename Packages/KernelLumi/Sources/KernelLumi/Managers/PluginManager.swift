import Foundation
import EditorContracts
import os
import SwiftUI

/// 内置插件管理器
///
/// 负责管理所有插件的注册、启动、查询和排序。
@MainActor
public final class PluginManager: ObservableObject {
    public private(set) var allPlugins: [LumiPlugin] = []

    private var plugins: [String: LumiPlugin] = [:]
    private var pluginOrder: [String] = []

    /// Kernel 引用
    weak var kernel: KernelLumiContainer?
    private weak var runtimeKernel: KernelLumi?

    // Message renderer registry
    private var messageRenderers: [String: LumiMessageRendererItem] = [:]
    private var messageRendererOrder: [String] = []

    // IDs registered through LumiPlugin.commandMenuGroups(kernel:).
    // Imperatively registered command groups are intentionally not tracked here.
    private var pluginCommandMenuGroupIDs: Set<String> = []

    // 运行时状态。
    private var enabledOverrides: [String: Bool] = [:]

    /// 插件启用状态变化时广播通知
    public func notifyEnabledPluginsDidChange() {
        kernel?.eventManager.postEnabledPluginsDidChange(object: self)
    }

    init() {}

    // MARK: - PluginManaging

    public func initializePlugins(_ plugins: [LumiPlugin], kernel: KernelLumi) async throws {
        self.kernel = kernel
        self.runtimeKernel = kernel

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

    /// 应用由 PluginManagerPlugin 读取的持久化状态。
    ///
    /// PluginManager 只负责运行时决策，不关心状态来自文件、数据库还是云端。
    /// 此方法必须在可配置插件启动前调用。
    public func applyPersistedPluginStates(_ overrides: [String: Bool]) {
        enabledOverrides = overrides
    }

    public func onBoot(kernel: KernelLumi) async throws {
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

    public func onReady(kernel: KernelLumi) async throws {
        for plugin in allPlugins {
            guard effectiveEnabled(for: plugin) else { continue }
            try await plugin.onReady(kernel: kernel)
        }

        // 注册容器激活观察者，当容器切换时通知所有插件
        kernel.workspace?.addContainerObserver { [weak self] containerID in
            guard let self else { return }
            Task { @MainActor in
                self.onContainerActivated(kernel: kernel, containerID: containerID)
            }
        }
    }

    public func onContainerActivated(kernel: KernelLumi, containerID: String) {
        // 可见性已在 LayoutManager.activateContainer(id:) 中自动应用
        // 此处仅广播给插件（用于非可见性的副作用）
        for plugin in allPlugins {
            guard effectiveEnabled(for: plugin) else { continue }
            plugin.onContainerActivated(kernel: kernel, containerID: containerID)
        }
    }

    /// 将外部打开的文件分发给已启用的插件。
    ///
    /// 按插件 `order` 从小到大询问，第一个返回 `true` 的插件接管该文件。
    /// - Returns: 是否有插件接管了该文件。
    @discardableResult
    public func dispatchOpenFile(_ url: URL, kernel: KernelLumi) -> Bool {
        for plugin in allPlugins {
            guard effectiveEnabled(for: plugin) else { continue }
            if plugin.openFile(kernel: kernel, url: url) {
                return true
            }
        }
        return false
    }

    public func plugin(id: String) -> LumiPlugin? {
        plugins[id]
    }

    public func plugin<T: LumiPlugin>(ofType type: T.Type) -> T? {
        allPlugins.first(where: { $0 is T }) as? T
    }

    public func registerPluginUIContributions(in kernel: KernelLumi) {
        self.kernel = kernel

        // 全量重建:先清空各 Provider 服务与 manager 自身的内部 registry,
        // 再按"有效启用"状态重新注册。这样禁用某插件时,其贡献会即时撤回。
        // 首次启动时各 registry 为空,清空为 no-op,不影响行为。
        clearInternalContributions()
        kernel.settings?.clearAllContributions()
        kernel.workspace?.clearAllContributions()
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
                kernel.workspace?.registerMenuBarContent(content)
            }
            for popup in plugin.menuBarPopupItems(kernel: kernel) {
                kernel.workspace?.registerMenuBarPopup(popup)
            }

            // Title Toolbar
            for item in plugin.titleToolbarItems(kernel: kernel) {
                kernel.workspace?.registerTitleToolbarItem(item)
            }

            // Panel
            for item in plugin.panelHeaderItems(kernel: kernel) {
                kernel.workspace?.registerPanelHeaderItem(item)
            }
            for item in plugin.panelBottomTabItems(kernel: kernel) {
                var tabItem = PanelBottomTabItem(
                    id: item.id,
                    title: item.title,
                    systemImage: item.systemImage,
                    content: item.makeView
                )
                tabItem.order = pluginOrder
                kernel.workspace?.registerPanelBottomTabItem(tabItem)
            }
            for item in plugin.panelRailTabItems(kernel: kernel) {
                var railItem = PanelRailTabItem(
                    id: item.id,
                    title: item.title,
                    systemImage: item.systemImage,
                    visibility: item.visibility,
                    requiresProjectSupport: item.requiresProjectSupport,
                    requiresActiveProject: item.requiresActiveProject,
                    requiresChatSupport: item.requiresChatSupport,
                    content: item.makeView
                )
                railItem.order = pluginOrder
                kernel.workspace?.registerPanelRailTabItem(railItem)
            }

            // View Containers
            for container in plugin.viewContainers(kernel: kernel) {
                let viewContainer: ViewContainerItem
                if let makeView = container.makeView {
                    viewContainer = ViewContainerItem(
                        id: container.id,
                        title: container.title,
                        systemImage: container.systemImage,
                        supportsProject: container.supportsProject,
                        railVisibility: container.railVisibility,
                        chatVisibility: container.chatVisibility,
                        panelHeaderVisibility: container.panelHeaderVisibility,
                        panelBodyVisibility: container.panelBodyVisibility,
                        panelBottomVisibility: container.panelBottomVisibility,
                        content: makeView
                    )
                } else {
                    viewContainer = ViewContainerItem(
                        id: container.id,
                        title: container.title,
                        systemImage: container.systemImage,
                        supportsProject: container.supportsProject,
                        railVisibility: container.railVisibility,
                        chatVisibility: container.chatVisibility,
                        panelHeaderVisibility: container.panelHeaderVisibility,
                        panelBodyVisibility: container.panelBodyVisibility,
                        panelBottomVisibility: container.panelBottomVisibility
                    )
                }
                var containerWithOrder = viewContainer
                containerWithOrder.order = pluginOrder
                kernel.workspace?.registerViewContainer(containerWithOrder)
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
                kernel.workspace?.registerChatSectionItem(chatItem)
            }
            for item in plugin.chatSectionToolbarItems(kernel: kernel) {
                var toolbarItem = ChatSectionToolbarItem(
                    id: item.id,
                    placement: item.placement,
                    content: item.makeView
                )
                toolbarItem.order = pluginOrder
                kernel.workspace?.registerChatSectionToolbarItem(toolbarItem)
            }
            for item in plugin.chatSectionToolbarBarItems(kernel: kernel) {
                var barItem = ChatSectionToolbarBarItem(
                    id: item.id,
                    content: item.makeView
                )
                barItem.order = pluginOrder
                kernel.workspace?.registerChatSectionToolbarBarItem(barItem)
            }
            for item in plugin.chatSectionHeaderItems(kernel: kernel) {
                var headerItem = ChatSectionHeaderItem(
                    id: item.id,
                    content: item.makeView
                )
                headerItem.order = pluginOrder
                kernel.workspace?.registerChatSectionHeaderItem(headerItem)
            }
            for item in plugin.chatSectionActionBarItems(kernel: kernel) {
                var actionBarItem = ChatSectionActionBarItem(
                    id: item.id,
                    placement: item.placement,
                    content: item.makeView
                )
                actionBarItem.order = pluginOrder
                kernel.workspace?.registerChatSectionActionBarItem(actionBarItem)
            }

            // Status Bar
            for item in plugin.statusBarItems(kernel: kernel) {
                kernel.workspace?.registerStatusBarItem(item)
            }

            // Settings
            for item in plugin.settingsTabItems(kernel: kernel) {
                kernel.settings?.registerSettingsTabItem(item)
            }
            for section in plugin.settingsSections(kernel: kernel) {
                kernel.settings?.registerSettingsSection(section)
            }
            for item in plugin.llmProviderSettingsItems(kernel: kernel) {
                kernel.settings?.registerLLMProviderSettingsItem(item)
            }

            // Root Overlays
            for item in plugin.rootOverlays(kernel: kernel) {
                var overlayItem = item
                overlayItem.order = pluginOrder
                kernel.workspace?.registerRootOverlayItem(overlayItem)
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

        // 容器注册完毕后，回填当前激活容器的可见性声明。
        // 持久化恢复（`LayoutPersistenceCoordinator.restore()`）发生在 `onReady` 阶段，
        // 此时容器还未注册，只能直接给 `activeViewContainerID` 赋值，绕过了
        // `activateContainer` → `onContainerActivated` 的可见性应用路径。
        // 因此启动/重建完成后必须在此处补一次 apply，否则 rail/chat 仍按默认值显示。
        // （首容器的自动选中已下沉到 `registerViewContainer`。）
        if let containerID = kernel.workspace?.activeViewContainerID {
            kernel.workspace?.applyContainerVisibility(for: containerID)
        }

    }

    /// Collects command menu groups declared by enabled plugins.
    ///
    /// Only groups previously registered through `LumiPlugin.commandMenuGroups(kernel:)`
    /// are removed during a rebuild. This preserves command groups registered directly
    /// through `kernel.command` by legacy plugins and core services.
    public func registerPluginCommandContributions(in kernel: KernelLumi) {
        self.kernel = kernel
        guard let command = kernel.command else { return }

        for id in pluginCommandMenuGroupIDs {
            command.unregisterCommandGroup(id: id)
        }

        var registeredIDs: Set<String> = []
        for plugin in allPlugins {
            guard effectiveEnabled(for: plugin) else { continue }
            for group in plugin.commandMenuGroups(kernel: kernel) {
                command.registerCommandGroup(group)
                registeredIDs.insert(group.id)
            }
        }
        pluginCommandMenuGroupIDs = registeredIDs
    }

    /// 收集所有插件贡献的 LLM Provider,并注册到内核的 `LLMProviderManaging` 服务。
    ///
    /// 调用时机:在 `KernelLumi.startup()` 的 `onReady` 之后。每个 LLM Provider 插件
    /// (Anthropic、OpenAI、…)只需实现 `LumiPlugin.llmProviders(kernel:)` 返回其实例,
    /// 无需再在 `onBoot/onReady` 里主动调用 `kernel.llmProvider?.registerLLMProvider(...)`。
    ///
    /// `LLMProviderManagerPlugin` 必须已经注册(其 `order = 10`,在内核启动时最先
    /// 完成),因此这里 `kernel.llmProvider` 一定可用;若不可用则抛错,不再静默。
    ///
    /// - Throws:
    ///   - `KernelLumiError.serviceNotAvailable("LLMProvider")` 当 manager 服务
    ///     未注册时。
    ///   - `KernelLumiError.llmProviderRegistrationFailed` 当某个 provider 的
    ///     `info.id` 为空时。
    public func registerLLMProviders(in kernel: KernelLumi) throws {
        self.kernel = kernel

        guard let manager = kernel.llmProvider else {
            throw KernelLumiError.serviceNotAvailable(service: "LLMProvider")
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
    /// 调用时机:在 `KernelLumi.startup()` 的 `onReady` 之后,且 `registerLLMProviders` 之后。
    /// 每个需要贡献工具的插件只需实现 `LumiPlugin.agentTools(kernel:)` 返回其实例,
    /// 无需再在 `onBoot/onReady` 里主动调用 `kernel.toolManager?.add(...)`。
    ///
    /// `ToolManagerPlugin` 必须已经注册(其 `order = 30`),因此这里 `kernel.toolManager` 一定可用;
    /// 若不可用则抛错,不再静默。
    ///
    /// - Throws:
    ///   - `KernelLumiError.serviceNotAvailable("AgentTool")` 当 manager 服务未注册时。
    public func registerAgentTools(in kernel: KernelLumi) throws {
        self.kernel = kernel

        guard let manager = kernel.toolManager else {
            throw KernelLumiError.serviceNotAvailable(service: "AgentTool")
        }

        manager.removeAll()
        // Build the ordinary tool set from plugin contributions.
        for plugin in allPlugins {
            guard effectiveEnabled(for: plugin) else { continue }
            let tools = plugin.agentTools(kernel: kernel)
            for tool in tools {
                manager.add(tool, pluginID: plugin.id)
            }
        }

    }

    /// 收集所有插件贡献的聊天起始提示词，并注册到内核的 `PromptSuggestionProviding` 服务。
    ///
    /// 调用时机：在 `KernelLumi.startup()` 的收集阶段，以及 `rebuildAllContributions`
    /// 中（插件启用/禁用后）。每个插件只需实现 `LumiPlugin.promptSuggestions(kernel:)`
    /// 返回其提示词，内核会按插件 `order` 盖戳并聚合。服务未注册时为 no-op。
    ///
    /// 收集范围：**所有可注册插件**（`policy.shouldRegister`），而非仅当前启用者。
    /// 这样禁用插件的提示词也会展示，并通过 `requiresEnable = true` 标记，供 UI 在点击时
    /// 「启用并发送」。永远无法启用的 `.disabled` 插件不参与收集。
    public func registerPromptSuggestions(in kernel: KernelLumi) {
        self.kernel = kernel
        guard let manager = kernel.promptSuggestions else { return }

        // 先清空再重新注册：启用态变化的插件其 requiresEnable 标记会被即时刷新。
        manager.clearAllContributions()
        for plugin in allPlugins {
            guard plugin.policy.shouldRegister else { continue }
            let isEnabled = effectiveEnabled(for: plugin)
            let pluginOrder = plugin.order
            for suggestion in plugin.promptSuggestions(kernel: kernel) {
                var item = LumiPromptSuggestion(
                    id: suggestion.id,
                    title: suggestion.title,
                    prompt: suggestion.prompt,
                    systemImage: suggestion.systemImage,
                    action: suggestion.action,
                    visibility: suggestion.visibility,
                    style: suggestion.style
                )
                item.order = pluginOrder
                item.pluginID = plugin.id
                item.requiresEnable = !isEnabled
                manager.registerPromptSuggestion(item)
            }
        }
    }

    /// 收集所有插件贡献的 Web 路由,并注册到内核的 `WebServerProviding` 服务。
    ///
    /// 调用时机:在 `KernelLumi.startup()` 的收集阶段,以及 `rebuildAllContributions`
    /// 中(插件启用/禁用后)。每个插件只需实现 `LumiPlugin.webRoutes(kernel:)`
    /// 返回其路由,内核按插件 `id` 归属,便于整体替换/撤回。
    /// 服务未注册(`kernel.webServer == nil`)时为 no-op。
    public func registerWebRoutes(in kernel: KernelLumi) {
        self.kernel = kernel
        guard let server = kernel.webServer else { return }

        // 全量重建:启用插件的贡献按插件整体写入(幂等替换);
        // 禁用插件的贡献按插件整体撤回。
        for plugin in allPlugins {
            if effectiveEnabled(for: plugin) {
                let routes = plugin.webRoutes(kernel: kernel)
                server.register(routes, forPlugin: plugin.id)
            } else {
                server.unregister(pluginID: plugin.id)
            }
        }
    }

    /// 全量重建所有插件贡献(Agent Tools + UI + Commands + LLM Provider + Editor Plugins)。
    ///
    /// 在插件启用/禁用后由宿主(`FactoryCore.subscribeToPluginChanges`)调用,
    /// 使被禁用插件的贡献即时撤回、被启用插件的贡献即时加入。
    ///
    /// - Agent Tools:先清空 ToolManager 再按有效启用状态重新注册。
    /// - UI 贡献:先 clear 各 Provider 再按有效启用状态重新注册。
    /// - LLM Provider:采用 diff 策略——注销已注册但不再属于有效集合的 provider,
    ///   再幂等注册有效集合,以保留用户当前选中的 provider/model(若仍可用)。
    public func rebuildAllContributions(in kernel: KernelLumi) {
        self.kernel = kernel

        // 1. Agent Tools 重建 — 必须在 UI 贡献重建之前,
        //    确保 settingsTabItems 创建视图时能读取到已注册的工具列表。
        if let toolManager = kernel.toolManager {
            toolManager.removeAll()
            for plugin in allPlugins {
                guard effectiveEnabled(for: plugin) else { continue }
                let tools = plugin.agentTools(kernel: kernel)
                for tool in tools {
                    toolManager.add(tool, pluginID: plugin.id)
                }
            }
        }

        // 2. UI 贡献重建
        registerPluginUIContributions(in: kernel)

        // 2.5 提示词贡献重建（撤回已禁用插件、加入新启用插件的提示词）
        registerPromptSuggestions(in: kernel)

        // 2.6 Web 路由重建(撤回已禁用插件的路由,加入新启用插件的路由)
        registerWebRoutes(in: kernel)

        // 3. Command 菜单贡献重建
        registerPluginCommandContributions(in: kernel)

        // 4. 编辑器贡献包重建（契约 V2）：启用 → 原子安装；禁用 → 撤回。
        registerEditorContributionBundles(in: kernel)

        // 5. LLM Provider 重建(diff)
        guard let manager = kernel.llmProvider else { return }
        let effectiveIDs = Set(
            allPlugins
                .filter { effectiveEnabled(for: $0) }
                .flatMap { $0.llmProviders(kernel: kernel).map { type(of: $0).info.id } }
        )
        for registered in manager.allLLMProviders() {
            let id = registered.providerInfo.id
            if !effectiveIDs.contains(id) {
                manager.unregisterLLMProvider(id: id)
            }
        }
        let collected = allPlugins
            .filter { effectiveEnabled(for: $0) }
            .flatMap { $0.llmProviders(kernel: kernel) }
        try? manager.registerLLMProviders(collected)
    }

    /// 收集并装配编辑器贡献包（契约 V2，重构方案 §9.2）。
    ///
    /// 只向已启用插件请求 Bundle；为每个 Bundle 盖可信 plugin id 与递增 generation
    /// （插件不能伪造归属），Host 按插件维度**原子安装**；一个插件失败只记录
    /// 日志、不影响其他插件。禁用插件的 Bundle 以 `nil` 撤回。
    public func registerEditorContributionBundles(in kernel: KernelLumi) {
        self.kernel = kernel
        guard let hosting = kernel.editorV2?.extensions else { return }

        Task { @MainActor in
            for plugin in allPlugins {
                let enabled = effectiveEnabled(for: plugin)
                guard enabled else {
                    // 运行时禁用：撤回该插件全部编辑器贡献（§9.2）。
                    if await pluginHasEditorBundle(plugin, kernel: kernel) {
                        try? await hosting.replaceBundle(for: plugin.id, with: nil)
                    }
                    continue
                }

                do {
                    let bundle = try await plugin.editorContributionBundle(kernel: kernel)
                    guard let bundle else { continue }
                    // 盖戳：覆盖插件自报的 pluginID/generation。
                    let stamped = bundle.stamped(pluginID: plugin.id, generation: 0)
                    try await hosting.replaceBundle(for: plugin.id, with: stamped)
                } catch {
                    // 单插件失败不回滚其他插件（§9.2）。
                    Self.editorBundleLogger.warning(
                        "editor bundle install failed: \(plugin.id, privacy: .public) — \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    /// 该插件是否会贡献编辑器 Bundle（决定禁用时是否需要撤回）。
    /// 编辑器贡献包装配日志。
    nonisolated static let editorBundleLogger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin-manager.editor-bundles"
    )

    private func pluginHasEditorBundle(_ plugin: any LumiPlugin, kernel: KernelLumi) async -> Bool {
        (try? await plugin.editorContributionBundle(kernel: kernel)) != nil
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

    /// 设置某个插件的运行时启用状态。
    ///
    /// 仅对可配置插件(`policy.isConfigurable`)生效;`alwaysOn` / `disabled` 为 no-op。
    /// 持久化由 PluginManagerPlugin 在调用此方法前后负责。
    @discardableResult
    public func setPluginEnabled(id: String, enabled: Bool) async -> Bool {
        guard let plugin = plugin(id: id), let runtimeKernel else { return false }
        guard plugin.policy.isConfigurable else { return false }
        let current = effectiveEnabled(for: plugin)
        guard current != enabled else { return false }

        enabledOverrides[id] = enabled
        // 立即通知 UI 更新,避免 Toggle 卡在旧状态
        objectWillChange.send()

        do {
            if enabled {
                try await plugin.onEnable(kernel: runtimeKernel)
            } else {
                try await plugin.onDisable(kernel: runtimeKernel)
            }
        } catch {
            // Lifecycle failure must not leave the manager claiming a state that
            // the plugin failed to enter.
            enabledOverrides[id] = current
            objectWillChange.send()
            notifyEnabledPluginsDidChange()
            return false
        }

        notifyEnabledPluginsDidChange()
        return true
    }

    /// 清除某个插件的运行时覆盖(回落到 policy 默认)。
    @discardableResult
    public func resetPluginEnabledState(id: String) async -> Bool {
        guard let plugin = plugin(id: id), let runtimeKernel else { return false }
        guard plugin.policy.isConfigurable else { return false }
        guard let override = enabledOverrides[id] else { return false }

        let defaultEnabled = plugin.policy.enabledByDefault
        guard override != defaultEnabled else {
            enabledOverrides.removeValue(forKey: id)
            objectWillChange.send()
            notifyEnabledPluginsDidChange()
            return true
        }

        enabledOverrides[id] = defaultEnabled
        // 立即通知 UI 更新,避免 Toggle 卡在旧状态
        objectWillChange.send()

        do {
            if defaultEnabled {
                try await plugin.onEnable(kernel: runtimeKernel)
            } else {
                try await plugin.onDisable(kernel: runtimeKernel)
            }
        } catch {
            enabledOverrides[id] = override
            objectWillChange.send()
            notifyEnabledPluginsDidChange()
            return false
        }

        enabledOverrides.removeValue(forKey: id)
        notifyEnabledPluginsDidChange()
        return true
    }
}
