import AppKit
import AgentToolKit
import LumiCoreKit
import LumiPluginRegistry
import Foundation
import SwiftUI
import ObjectiveC.runtime
import Combine
import os

/// 插件 VM，管理插件的生命周期和 UI 贡献
///
/// AppPluginVM 是 Lumi 插件系统的核心管理器，负责：
/// - 自动发现并注册所有插件
/// - 管理插件的生命周期（注册、启用、禁用）
/// - 聚合所有插件提供的 UI 扩展点
/// - 处理插件设置的持久化
///
/// ## 插件发现机制
///
/// AppPluginVM 优先使用 `LumiPluginRegistry` 提供的显式插件注册表，避免启动时扫描整个
/// Objective-C runtime。兼容扫描仅在注册表为空或显式启用调试开关时运行。
/// 插件按 `order` 属性排序，确保按正确顺序加载。
///
/// ## 线程安全
///
/// ⚠️ 注意：此类标记为 `@MainActor`，所有成员访问都必须在主线程。
/// 这确保了 UI 相关的操作（如插件注册、视图获取）的线程安全性。
///
/// ## 初始化规则
///
/// 由 `RootContainer` 持有（`.shared` 单例）并通过 `.environmentObject()` 注入。
/// View 通过 `@EnvironmentObject var pluginVM: AppPluginVM` 访问。
@MainActor
final class AppPluginVM: ObservableObject, SuperLog {
    /// 全局单例
    ///
    /// 整个应用共享同一个 AppPluginVM 实例。
    /// 使用 `shared` 属性访问全局实例。
    @MainActor static let shared = AppPluginVM()

    /// 日志标识符
    ///
    /// 用于日志输出的前缀标识。
    nonisolated static let emoji = "🔌"

    /// 是否启用详细日志输出
    nonisolated static let verbose: Bool = true
    /// 已加载的插件列表
    ///
    /// 包含所有成功注册的插件实例。
    @Published private(set) var plugins: [any SuperPlugin] = []
    
    /// 插件是否已加载完成
    ///
    /// 用于在 UI 中显示加载状态。
    /// 当插件正在加载时为 false，加载完成后为 true。
    @Published private(set) var isLoaded: Bool = false

    /// 插件设置存储
    ///
    /// 负责持久化用户的插件配置（启用/禁用状态）。
    /// 当设置变化时，会触发 UI 更新。
    private let settingsStore: AppPluginSettingsVM
    
    /// Combine 订阅集合
    ///
    /// 存储所有 Combine 订阅，用于在 deinit 时取消。
    /// 防止内存泄漏。
    private var cancellables = Set<AnyCancellable>()
    private var viewContainerItemsCache: [ViewContainerItem]?
    private var bottomPanelTabsCache: (key: String, tabs: [BottomPanelTab])?
    private var railTabsCache: (key: String, tabs: [RailTab])?
    private var sidebarLeadingToolbarItemsCache: (key: String, items: [SidebarToolbarItem])?
    private var sidebarTrailingToolbarItemsCache: (key: String, items: [SidebarToolbarItem])?
    private var enabledPluginIDs = Set<String>()

    // MARK: - Tools Cache

    private var cachedSuperSendMiddlewares: [SuperSendMiddleware]?
    /// 已发现的 LLM 供应商类型
    ///
    /// 在插件自动发现阶段，从所有实现了 `llmProviderType()` 的插件中收集。
    /// 需要在 `RootViewContainer` 初始化时通过 `registerLLMProviders(to:)` 注册到 `LLMProviderRegistry`。
    private(set) var discoveredLLMProviderTypes: [any SuperLLMProvider.Type] = []

    /// 初始化插件 VM
    ///
    /// - Parameters:
    ///   - settingsStore: 插件设置存储实例，默认使用单例
    ///   - autoDiscover: 是否自动发现插件，默认为 true
    ///
    /// 如果 `autoDiscover` 为 true，会立即扫描并注册所有插件。
    /// 设为 false 可以延迟加载，常用于测试场景。
    init(settingsStore: AppPluginSettingsVM = AppPluginSettingsVM.shared, autoDiscover: Bool = true) {
        self.settingsStore = settingsStore

        if autoDiscover {
            autoDiscoverAndRegisterPlugins()
        }

        // 订阅设置变化，当设置改变时触发 UI 更新
        settingsStore.$settings
            .sink { [weak self] _ in
                self?.reconcilePluginEnabledStates()
            }
            .store(in: &cancellables)

    }

    private func clearPluginMetadataCaches() {
        viewContainerItemsCache = nil
        bottomPanelTabsCache = nil
        railTabsCache = nil
        sidebarLeadingToolbarItemsCache = nil
        sidebarTrailingToolbarItemsCache = nil
    }

    private func activeIconCacheKey(_ activeIcon: String?) -> String {
        "\(activeIcon ?? "<nil>")|\(plugins.count)"
    }

    private func invalidatePluginAggregates() {
        clearPluginMetadataCaches()
        cachedSuperSendMiddlewares = nil
    }

    #if DEBUG
    func replacePluginsForTesting(_ plugins: [any SuperPlugin]) {
        self.plugins = plugins
        self.isLoaded = true
        self.discoveredLLMProviderTypes = []
        enabledPluginIDs.removeAll()
        reconcilePluginEnabledStates()
    }
    #endif

    private func reconcilePluginEnabledStates() {
        let nextEnabledPluginIDs = Set(
            plugins
                .filter { isPluginEnabled($0) }
                .map { $0.instanceLabel }
        )

        for plugin in plugins {
            let pluginID = plugin.instanceLabel
            let wasEnabled = enabledPluginIDs.contains(pluginID)
            let isEnabled = nextEnabledPluginIDs.contains(pluginID)

            guard wasEnabled != isEnabled else { continue }

            if isEnabled {
                plugin.onEnable()
            } else {
                plugin.onDisable()
            }
        }

        enabledPluginIDs = nextEnabledPluginIDs
        invalidatePluginAggregates()
        objectWillChange.send()
        NotificationCenter.default.post(name: Notification.Name("toolSourcesDidChange"), object: nil)
    }

    // MARK: - Agent Tools Aggregation

    func collectAgentTools(context: ToolContext) -> [SuperAgentTool] {
        let enabledPlugins = plugins.filter { isPluginEnabled($0) }
        var tools: [(pluginOrder: Int, tool: SuperAgentTool)] = []

        for plugin in enabledPlugins {
            let pluginOrder = plugin.pluginOrder
            for tool in plugin.agentTools(context: context) {
                tools.append((pluginOrder: pluginOrder, tool: tool))
            }
        }

        return tools.sorted { a, b in
            if a.pluginOrder != b.pluginOrder { return a.pluginOrder < b.pluginOrder }
            return a.tool.name < b.tool.name
        }.map(\.tool)
    }

    func collectSubAgentDefinitions() -> [any SubAgentDefinitionProtocol] {
        let enabledPlugins = plugins.filter { isPluginEnabled($0) }
        var definitions: [(pluginOrder: Int, definition: any SubAgentDefinitionProtocol)] = []

        for plugin in enabledPlugins {
            let pluginOrder = plugin.pluginOrder
            for definition in plugin.subAgentDefinitions() {
                definitions.append((pluginOrder: pluginOrder, definition: definition))
            }
        }

        return definitions.sorted { a, b in
            if a.pluginOrder != b.pluginOrder { return a.pluginOrder < b.pluginOrder }
            return a.definition.id < b.definition.id
        }.map(\.definition)
    }

    // MARK: - Send Middleware

    func getSuperSendMiddlewares() -> [SuperSendMiddleware] {
        if let cachedSuperSendMiddlewares {
            return cachedSuperSendMiddlewares
        }

        let enabledPlugins = plugins.filter { isPluginEnabled($0) }
        var items: [(pluginOrder: Int, mwOrder: Int, middleware: SuperSendMiddleware)] = []

        for plugin in enabledPlugins {
            let pluginOrder = plugin.pluginOrder
            for m in plugin.sendMiddlewares() {
                items.append((pluginOrder: pluginOrder, mwOrder: m.order, middleware: m))
            }
        }

        let sorted = items.sorted { a, b in
            if a.pluginOrder != b.pluginOrder { return a.pluginOrder < b.pluginOrder }
            if a.mwOrder != b.mwOrder { return a.mwOrder < b.mwOrder }
            return a.middleware.id < b.middleware.id
        }.map(\.middleware)

        cachedSuperSendMiddlewares = sorted
        return sorted
    }

    /// 自动发现并注册所有插件。
    ///
    /// 主注册表由 `LumiPluginRegistry` 显式维护，
    /// 避免依赖 Objective-C runtime 枚举 Swift Package 中的 actor 类型。
    /// runtime 扫描仅作为兼容兜底，用于捕获仍直接声明在 app target 中、
    /// 但尚未进入生成表的 `Lumi.*Plugin` 类型。
    private func autoDiscoverAndRegisterPlugins() {
        // 插件列表将被重建，相关缓存一并清空
        invalidatePluginAggregates()
        enabledPluginIDs.removeAll()

        var discoveredItems: [(instance: any SuperPlugin, className: String, order: Int)] = []
        var discoveredPluginIDs = Set<String>()

        func appendGeneratedOrRuntimePlugin(_ instance: any SuperPlugin, className: String) {
            guard instance.pluginPolicy != .disabled else { return }
            guard discoveredPluginIDs.insert(instance.instanceLabel).inserted else { return }

            discoveredItems.append((instance, className, instance.pluginOrder))
            if Self.verbose {
                AppLogger.core.info("\(self.t)发现插件: \(instance.pluginID) (order: \(instance.pluginOrder))")
            }
        }

        let generatedPlugins = LumiPluginRegistry.GeneratedPluginRegistry.plugins
        for packagedPlugin in generatedPlugins {
            let plugin = AnyPackagePluginAdapter(packaged: packagedPlugin)
            appendGeneratedOrRuntimePlugin(
                plugin,
                className: String(describing: type(of: packagedPlugin))
            )
        }

        if generatedPlugins.isEmpty || ProcessInfo.processInfo.environment["LUMI_ENABLE_RUNTIME_PLUGIN_SCAN"] == "1" {
            var count: UInt32 = 0
            if let classList = objc_copyClassList(&count) {
                defer { free(UnsafeMutableRawPointer(classList)) }

                let classes = UnsafeBufferPointer(start: classList, count: Int(count))
                if Self.verbose { AppLogger.core.info("\(self.t)扫描 \(classes.count) 个类作为兼容兜底") }

                for i in 0 ..< classes.count {
                    let cls: AnyClass = classes[i]
                    let className = NSStringFromClass(cls)

                    guard className.hasPrefix("Lumi."), className.hasSuffix("Plugin") else { continue }
                    guard let pluginClass = cls as? any SuperPlugin.Type else { continue }

                    appendGeneratedOrRuntimePlugin(pluginClass.shared, className: className)
                }
            }
        }

        guard !discoveredItems.isEmpty else {
            self.plugins = []
            self.isLoaded = true
            self.discoveredLLMProviderTypes = []
            NotificationCenter.postPluginsDidLoad()
            if Self.verbose {
                AppLogger.core.warning("\(self.t)未发现任何插件")
            }
            return
        }
        
        // 按 order 升序排序，确保核心插件先加载
        discoveredItems.sort { $0.order < $1.order }
        
        // 更新插件列表
        let sortedPlugins = discoveredItems.map { $0.instance }
        self.plugins = sortedPlugins
        self.isLoaded = true

        // 插件已更新，清空聚合缓存，避免在插件加载前被读取后永久缓存为空。
        invalidatePluginAggregates()

        // 从插件中收集 LLM 供应商类型
        var providerTypes: [any SuperLLMProvider.Type] = []
        var providerDiagnostics: [String] = []
        for plugin in sortedPlugins {
            if let providerType = plugin.llmProviderType() {
                providerTypes.append(providerType)
                providerDiagnostics.append("\(plugin.pluginID)->\(providerType.id)")
            } else {
                providerDiagnostics.append("\(plugin.pluginID)->nil")
            }
        }
        self.discoveredLLMProviderTypes = providerTypes

        // 调用生命周期钩子
        for plugin in sortedPlugins {
            plugin.onRegister()
            // 如果插件被启用，调用 onEnable
            if self.isPluginEnabled(plugin) {
                plugin.onEnable()
                enabledPluginIDs.insert(plugin.instanceLabel)
            }
        }

        // 从插件中收集消息渲染器并注册到 AppMessageRendererVM
        var allRenderers: [any SuperMessageRenderer] = []
        for plugin in sortedPlugins {
            let pluginRenderers = plugin.messageRenderers()
            allRenderers.append(contentsOf: pluginRenderers)
        }
        if !allRenderers.isEmpty {
            AppMessageRendererVM.shared.register(allRenderers)
        }
        
        // 发送通知，告知其他组件插件加载完成
        NotificationCenter.postPluginsDidLoad()
        
        if Self.verbose {
            AppLogger.core.info("\(self.t)✅ Auto-discovery complete. Loaded \(sortedPlugins.count) plugins, \(providerTypes.count) LLM providers, \(allRenderers.count) message renderers.")
        }
    }
    
    /// 获取插件的准入资格
    ///
    /// 将三道关卡的判断逻辑封装为 `PluginEligibility`，
    /// 外部通过 `eligibility.isEligible` / `eligibility.shouldRegister` 等属性即可完成判断。
    ///
    /// - Parameter plugin: 要检查的插件
    /// - Returns: 封装了完整准入判断的资格对象
    func eligibility(for plugin: any SuperPlugin) -> PluginEligibility {
        return PluginEligibility(
            policy: plugin.pluginPolicy,
            userEnabled: settingsStore.isPluginEnabled(plugin.instanceLabel, defaultEnabled: plugin.pluginEnabledByDefault)
        )
    }

    /// 检查插件是否被用户启用
    ///
    /// 判断逻辑：
    /// 1. 如果插件不可配置（`isConfigurable = false`），始终返回 true
    /// 2. 如果插件可配置，从用户设置中读取启用状态；
    ///    若用户未手动配置过，则回退到插件的 `enabledByDefault` 静态属性作为默认值
    ///
    /// - Parameter plugin: 要检查的插件
    /// - Returns: 如果插件被启用则返回 true
    func isPluginEnabled(_ plugin: any SuperPlugin) -> Bool {
        eligibility(for: plugin).isEligible
    }

    /// 获取所有启用插件的根视图包裹
    ///
    /// 将所有启用插件提供的根视图包装器依次应用于内容视图。
    /// 包装顺序与插件的 `order` 顺序一致。
    ///
    /// - Parameter content: 原始内容视图
    /// - Returns: 经过所有插件依次包裹后的视图
    func getRootViewWrapper<Content: View>(@ViewBuilder content: () -> Content) -> AnyView {
        var wrapped: AnyView = AnyView(content())

        for plugin in plugins where isPluginEnabled(plugin) {
            wrapped = plugin.wrapRoot(wrapped)
        }

        return wrapped
    }

    /// 获取右侧栏根视图包裹
    ///
    /// 将所有启用插件提供的右侧栏包装器依次应用于右侧栏内容。
    /// 用于右侧栏范围内的拖放检测、浮层提示等局部能力。
    func getRightSidebarRootWrapper<Content: View>(
        context: PluginContext,
        @ViewBuilder content: () -> Content
    ) -> AnyView {
        var wrapped: AnyView = AnyView(content())

        for plugin in plugins where isPluginEnabled(plugin) {
            wrapped = plugin.wrapRightSidebarRoot(wrapped, context: context)
        }

        return wrapped
    }

    /// 获取所有插件的工具栏前导视图
    ///
    /// 收集所有启用插件提供的工具栏左侧视图。
    /// 这些视图将在工具栏左侧水平排列显示。
    ///
    /// - Returns: 工具栏前导视图数组
    func getToolbarLeadingViews(context: PluginContext) -> [AnyView] {
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addToolBarLeadingView(context: context) }
    }

    /// 获取所有插件的工具栏中间视图
    ///
    /// 收集所有启用插件提供的工具栏中间视图。
    /// 这些视图将在工具栏中间位置水平排列显示。
    ///
    /// - Returns: 工具栏中间视图数组
    func getToolbarCenterViews(context: PluginContext) -> [AnyView] {
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addToolBarCenterView(context: context) }
    }

    /// 获取所有插件的工具栏右侧视图
    ///
    /// 收集所有启用插件提供的工具栏右侧视图。
    /// 这些视图将在工具栏右侧水平排列显示。
    ///
    /// - Returns: 工具栏右侧视图数组
    func getToolbarTrailingViews(context: PluginContext) -> [AnyView] {
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addToolBarTrailingView(context: context) }
    }

    /// 获取所有视图容器项（用于左侧活动栏）
    ///
    /// 仅收集各插件通过 `addViewContainer()` 提供的入口信息，
    /// 不触发 `makeView()`。用于渲染活动栏图标按钮。
    ///
    /// 如果发现两个插件提供了相同的 icon，会保留先加载插件的入口并跳过后续冲突项。
    func getViewContainerItems() -> [ViewContainerItem] {
        if let viewContainerItemsCache {
            return viewContainerItemsCache
        }
        let enabledPlugins = plugins.filter { isPluginEnabled($0) }
        var items: [ViewContainerItem] = []
        var seenIcons: [String: String] = [:]  // icon -> plugin id

        for plugin in enabledPlugins {
            guard let item = plugin.addViewContainer() else { continue }
            let pluginId = plugin.instanceLabel
            let icon = item.icon

            if let existingPluginId = seenIcons[icon] {
                AppLogger.core.error(
                    "\(self.t)Duplicate view container icon \"\(icon)\" from \(pluginId); keeping \(existingPluginId)'s entry and skipping the duplicate."
                )
                continue
            }
            seenIcons[icon] = pluginId
            items.append(item)
        }
        viewContainerItemsCache = items
        return items
    }

    /// 当前激活的活动栏图标是否在 `allowedIcons` 中。
    func isActiveViewContainerIcon(_ activeIcon: String?, in allowedIcons: [String]) -> Bool {
        guard let activeIcon else { return false }
        return allowedIcons.contains(activeIcon)
    }

    /// 获取当前激活的视图容器
    ///
    /// 根据 activeIcon 查找匹配的插件容器。只会有一个插件匹配。
    func getActiveViewContainer(activeIcon: String?) -> ViewContainerItem? {
        guard let activeIcon else { return nil }
        return getViewContainerItems().first { $0.icon == activeIcon }
    }

    /// 获取当前激活插件的所有 Panel Header 视图
    ///
    /// 收集所有启用插件通过 `addPanelHeaderView(context:)` 提供的 header 视图，
    /// 按插件 `order` 升序垂直堆叠（order 小的在上，大的在下）。
    ///
    /// - Returns: Panel Header 视图数组
    func getActivePanelHeaderViews(context: PluginContext) -> [AnyView] {
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addPanelHeaderView(context: context) }
    }

    /// 获取所有插件提供的底部面板标签页
    ///
    /// 收集所有启用插件通过 `addBottomPanelTabs()` 提供的标签页，
    /// 按 priority 升序排列。
    func getBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] {
        let key = activeIconCacheKey(context.activeIcon)
        if let cached = bottomPanelTabsCache, cached.key == key {
            return cached.tabs
        }
        let tabs = plugins
            .filter { isPluginEnabled($0) }
            .flatMap { $0.addBottomPanelTabs(context: context) }
            .sorted { $0.priority < $1.priority }
        bottomPanelTabsCache = (key, tabs)
        return tabs
    }

    /// 获取指定底部面板 Tab 对应的内容视图
    func getBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? {
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addBottomPanelContentView(tabId: tabId, context: context) }
            .first
    }

    /// 当前是否有底部面板标签页
    func hasBottomPanelTabs(context: PluginContext) -> Bool {
        !getBottomPanelTabs(context: context).isEmpty
    }

    /// 当前是否有面板视图
    ///
    /// 用于布局决策：有面板时使用中间栏 + 右侧栏分栏，无时仅显示右侧栏。
    func hasPanels() -> Bool {
        plugins
            .filter { isPluginEnabled($0) }
            .contains { $0.addViewContainer() != nil }
    }

    /// 聚合所有插件提供的 Rail 标签页
    ///
    /// 收集所有启用插件通过 `addRailTabs()` 提供的标签页，
    /// 按 priority 升序排列。
    func getRailTabs(context: PluginContext) -> [RailTab] {
        let key = activeIconCacheKey(context.activeIcon)
        if let cached = railTabsCache, cached.key == key {
            return cached.tabs
        }
        let tabs = plugins
            .filter { isPluginEnabled($0) }
            .flatMap { $0.addRailTabs(context: context) }
            .sorted { $0.priority < $1.priority }
        railTabsCache = (key, tabs)
        return tabs
    }

    /// 获取指定 Rail tab 对应的内容视图
    func getRailContentView(tabId: String, context: PluginContext) -> AnyView? {
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addRailContentView(tabId: tabId, context: context) }
            .first
    }

    /// 当前是否有 Rail 标签页
    func hasRailTabs(context: PluginContext) -> Bool {
        !getRailTabs(context: context).isEmpty
    }

    /// 获取所有插件提供的右侧栏 Section 视图
    ///
    /// 收集所有启用插件通过 `addSidebarSections()` 提供的 Section 视图，
    /// 按插件 `order` 升序扁平化排列（order 小的在上，大的在下）。
    /// 内核将这些 Section 使用 VStack 垂直堆叠在右侧栏中。
    ///
    /// - Returns: 右侧栏 Section 视图数组
    func getSidebarSections(context: PluginContext) -> [AnyView] {
        return plugins
            .filter { isPluginEnabled($0) }
            .flatMap { $0.addSidebarSections(context: context) }
    }

    /// 当前是否有右侧栏 Section 视图
    func hasSidebars(context: PluginContext) -> Bool {
        !getSidebarSections(context: context).isEmpty
    }

    // MARK: - Sidebar Toolbar Items

    /// 聚合所有插件提供的右侧栏底部工具栏左侧项
    ///
    /// 收集所有启用插件通过 `addSidebarLeadingToolbarItems()` 提供的工具栏项，
    /// 按 `priority` 升序排列。
    func getSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        let key = activeIconCacheKey(context.activeIcon)
        if let cached = sidebarLeadingToolbarItemsCache, cached.key == key {
            return cached.items
        }
        let items = plugins
            .filter { isPluginEnabled($0) }
            .flatMap { $0.addSidebarLeadingToolbarItems(context: context) }
            .sorted { $0.priority < $1.priority }
        sidebarLeadingToolbarItemsCache = (key, items)
        return items
    }

    /// 聚合所有插件提供的右侧栏底部工具栏右侧项
    ///
    /// 收集所有启用插件通过 `addSidebarTrailingToolbarItems()` 提供的工具栏项，
    /// 按 `priority` 升序排列。
    func getSidebarTrailingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        let key = activeIconCacheKey(context.activeIcon)
        if let cached = sidebarTrailingToolbarItemsCache, cached.key == key {
            return cached.items
        }
        let items = plugins
            .filter { isPluginEnabled($0) }
            .flatMap { $0.addSidebarTrailingToolbarItems(context: context) }
            .sorted { $0.priority < $1.priority }
        sidebarTrailingToolbarItemsCache = (key, items)
        return items
    }

    /// 获取指定右侧栏工具栏项对应的自定义按钮视图
    func getSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addSidebarToolbarItemView(itemId: itemId, context: context) }
            .first
    }

    /// 当前是否有右侧栏工具栏项
    func hasSidebarToolbarItems(context: PluginContext) -> Bool {
        !getSidebarLeadingToolbarItems(context: context).isEmpty || !getSidebarTrailingToolbarItems(context: context).isEmpty
    }

    /// 获取所有插件提供的菜单栏弹窗视图
    ///
    /// 收集所有启用插件提供的菜单栏弹窗视图。
    /// 当用户点击菜单栏图标时显示。
    /// 每个插件可以提供多个弹窗视图，所有视图会被扁平化合并。
    ///
    /// - Returns: 菜单栏弹窗视图数组
    func getMenuBarPopupViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .flatMap { $0.addMenuBarPopupViews() }
    }

    /// 获取所有插件提供的菜单栏内容视图
    ///
    /// 收集所有启用插件提供的菜单栏内容视图。
    /// 这些视图直接显示在菜单栏图标位置。
    ///
    /// - Returns: 菜单栏内容视图数组
    func getMenuBarContentViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addMenuBarContentView() }
    }

    /// 获取所有插件提供的状态栏左侧视图（用于 Agent 模式底部状态栏）
    ///
    /// 收集所有启用插件提供的状态栏左侧视图。
    /// 状态栏位于 Agent 模式底部，用于显示状态信息、操作提示等内容。
    /// 多个插件的状态栏视图会水平排列显示在左侧。
    ///
    /// - Parameter context: 由调用方组装的插件上下文
    /// - Returns: 状态栏左侧视图数组
    func getStatusBarLeadingViews(context: PluginContext) -> [AnyView] {
        let views = plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addStatusBarLeadingView(context: context) }

        return views
    }

    /// 获取所有插件提供的状态栏中间视图（用于 Agent 模式底部状态栏）
    ///
    /// 收集所有启用插件提供的状态栏中间视图。
    /// 状态栏位于 Agent 模式底部，用于显示状态信息、操作提示等内容。
    /// 多个插件的状态栏视图会水平排列显示在中间。
    ///
    /// - Parameter context: 由调用方组装的插件上下文
    /// - Returns: 状态栏中间视图数组
    func getStatusBarCenterViews(context: PluginContext) -> [AnyView] {
        let views = plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addStatusBarCenterView(context: context) }

        return views
    }

    /// 获取所有插件提供的状态栏右侧视图（用于 Agent 模式底部状态栏）
    ///
    /// 收集所有启用插件提供的状态栏右侧视图。
    /// 状态栏位于 Agent 模式底部，用于显示状态信息、操作提示等内容。
    /// 多个插件的状态栏视图会水平排列显示在右侧。
    ///
    /// - Parameter context: 由调用方组装的插件上下文
    /// - Returns: 状态栏右侧视图数组
    func getStatusBarTrailingViews(context: PluginContext) -> [AnyView] {
        let views = plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addStatusBarTrailingView(context: context) }

        return views
    }

    /// 获取所有插件的设置视图信息
    ///
    /// 收集所有可配置且已启用插件的设置视图。
    /// 用于在设置面板中展示插件配置选项。
    ///
    /// - Returns: 包含插件 ID、名称、图标和视图的元组数组
    func getPluginSettingsViews() -> [(id: String, name: String, icon: String, view: AnyView)] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { plugin -> (String, String, String, AnyView)? in
                guard let view = plugin.addSettingsView() else { return nil }
                return (plugin.pluginID, plugin.pluginDisplayName, plugin.pluginIconName, view)
            }
    }

    /// 将已发现的 LLM 供应商注册到供应商注册表
    ///
    /// 在 `RootViewContainer` 初始化时调用，将所有通过插件发现的 LLM 供应商
    /// 统一注册到 `LLMProviderRegistry`。
    ///
    /// - Parameter registry: 供应商注册表
    func registerLLMProviders(to registry: LLMProviderRegistry) {
        registry.register(discoveredLLMProviderTypes)
    }

    // MARK: - Category Aggregation

    /// 获取按分类分组的可配置插件列表
    ///
    /// 将所有可配置插件按 ``PluginCategory`` 分组，
    /// 分类按 ``PluginCategory/sortOrder`` 升序排列，
    /// 分类内插件按 ``SuperPlugin/order`` 升序排列。
    func getConfigurablePluginsGroupedByCategory() -> [(category: PluginCategory, plugins: [any SuperPlugin])] {
        let configurable = plugins.filter(\.pluginIsConfigurable)
        let grouped = Dictionary(grouping: configurable) { $0.pluginCategory }
        return grouped
            .map { (category: $0.key, plugins: $0.value.sorted { $0.pluginOrder < $1.pluginOrder }) }
            .sorted { $0.category.sortOrder < $1.category.sortOrder }
    }

    /// 获取所有启用插件提供的主题贡献（按插件 `order` 稳定排序，并写入 ``ThemeSortKey``）
    @MainActor
    func getThemeContributions() -> [LumiUIThemeContribution] {
        let enabledPlugins = plugins.filter { isPluginEnabled($0) }
        var merged: [(pluginOrder: Int, item: LumiUIThemeContribution)] = []

        for plugin in enabledPlugins {
            let pluginOrder = plugin.pluginOrder
            for item in plugin.addThemeContributions() {
                merged.append((
                    pluginOrder,
                    LumiUIThemeContribution(
                        sortKey: ThemeSortKey(pluginOrder: pluginOrder, themeId: item.id),
                        chromeTheme: item.chromeTheme,
                        editorThemeId: item.editorThemeId,
                        uiTheme: item.uiTheme,
                        attachments: item.attachments
                    )
                ))
            }
        }

        let sorted = merged.sorted { lhs, rhs in
            if lhs.pluginOrder != rhs.pluginOrder { return lhs.pluginOrder < rhs.pluginOrder }
            return lhs.item.id.localizedCaseInsensitiveCompare(rhs.item.id) == .orderedAscending
        }.map(\.item)

        var seen = Set<String>()
        var result: [LumiUIThemeContribution] = []
        for item in sorted {
            if seen.contains(item.id) { continue }
            seen.insert(item.id)
            result.append(item)
        }
        return result
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
