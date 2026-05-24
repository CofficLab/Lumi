import AppKit
import AgentToolKit
import LumiPluginKit
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
/// AppPluginVM 使用 Objective-C Runtime 扫描所有以 "Lumi." 开头
/// 且以 "Plugin" 结尾的类，自动创建实例并注册。
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
    /// 面板图标项（仅用于活动栏图标渲染，不包含视图）
    struct PanelIconItem: Identifiable, Equatable {
        let id: String
        let title: String
        let icon: String

        static func == (lhs: PanelIconItem, rhs: PanelIconItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// 面板视图项（用于左侧活动栏注册的统一入口）
    struct PanelItem: Identifiable, Equatable {
        let id: String
        let title: String
        let icon: String
        let view: AnyView
        
        static func == (lhs: PanelItem, rhs: PanelItem) -> Bool {
            lhs.id == rhs.id
        }
    }



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

    /// 当前被激活的 ActivityBar 图标（SF Symbol 名称）
    ///
    /// 当用户点击活动栏图标时更新。内核将其传递给 `addPanelView(activeIcon:)`，
    /// 插件通过比较 `activeIcon` 与自己的 `addPanelIcon()` 返回值来决定是否提供面板视图。
    ///
    /// 持久化由 LayoutPlugin 插件负责，AppPluginVM 不直接读写磁盘。
    @Published var activePanelIcon: String?

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
    private var panelIconItemsCache: [PanelIconItem]?
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
    private init(settingsStore: AppPluginSettingsVM = AppPluginSettingsVM.shared, autoDiscover: Bool = true) {
        self.settingsStore = settingsStore

        // activePanelIcon 不再从磁盘恢复，由 LayoutPlugin 在视图出现时恢复

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
        panelIconItemsCache = nil
        bottomPanelTabsCache = nil
        railTabsCache = nil
        sidebarLeadingToolbarItemsCache = nil
        sidebarTrailingToolbarItemsCache = nil
    }

    private func activeIconCacheKey() -> String {
        "\(activePanelIcon ?? "<nil>")|\(plugins.count)"
    }

    private func invalidatePluginAggregates() {
        clearPluginMetadataCaches()
        cachedSuperSendMiddlewares = nil
    }

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
            let pluginOrder = type(of: plugin).order
            for tool in plugin.agentTools(context: context) {
                tools.append((pluginOrder: pluginOrder, tool: tool))
            }
        }

        return tools.sorted { a, b in
            if a.pluginOrder != b.pluginOrder { return a.pluginOrder < b.pluginOrder }
            return a.tool.name < b.tool.name
        }.map(\.tool)
    }

    // MARK: - Send Middleware

    func getSuperSendMiddlewares() -> [SuperSendMiddleware] {
        if let cachedSuperSendMiddlewares {
            return cachedSuperSendMiddlewares
        }

        let enabledPlugins = plugins.filter { isPluginEnabled($0) }
        var items: [(pluginOrder: Int, mwOrder: Int, middleware: SuperSendMiddleware)] = []

        for plugin in enabledPlugins {
            let pluginOrder = type(of: plugin).order
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

    /// 自动发现并注册所有插件
    ///
    /// 使用 Objective-C Runtime 扫描所有符合插件命名规范的类：
    /// - 类名以 "Lumi." 开头
    /// - 类名以 "Plugin" 结尾
    ///
    /// 扫描过程：
    /// 1. 获取所有类列表
    /// 2. 筛选符合条件的类
    /// 3. 创建 Actor 实例
    /// 4. 按 order 排序
    /// 5. 调用生命周期钩子
    ///
    /// 扫描完成后会发送 `PluginsDidLoad` 通知。
    private func autoDiscoverAndRegisterPlugins() {
        // 插件列表将被重建，相关缓存一并清空
        invalidatePluginAggregates()
        enabledPluginIDs.removeAll()

        var count: UInt32 = 0
        guard let classList = objc_copyClassList(&count) else { return }
        defer { free(UnsafeMutableRawPointer(classList)) }
        
        let classes = UnsafeBufferPointer(start: classList, count: Int(count))
        // 临时存储，包含 (实例，类名，顺序)
        var discoveredItems: [(instance: any SuperPlugin, className: String, order: Int)] = []
        var pluginClassNames: [String] = []
        
        if Self.verbose { AppLogger.core.info("\(self.t)扫描 \(classes.count) 个类") }

        for i in 0 ..< classes.count {
            let cls: AnyClass = classes[i]
            let className = NSStringFromClass(cls)
            
            // 筛选条件：Lumi 命名空间且以 Plugin 结尾的类
            guard className.hasPrefix("Lumi."), className.hasSuffix("Plugin") else { continue }
            
            guard let pluginClass = cls as? any SuperPlugin.Type else {
                continue
            }

            // 统一通过插件类型暴露的共享实例拿到 Actor，避免通过 ObjC Runtime
            // 绕过 actor 初始化语义，也避免给 actor 引入额外的同步初始化要求。
            let instance = pluginClass.shared
            
            // 检查插件是否启用
            let pluginType = type(of: instance)
            if pluginType.enable {
                discoveredItems.append((instance, className, pluginType.order))
                pluginClassNames.append(className)
                if Self.verbose {
                    AppLogger.core.info("\(self.t)发现插件: \(pluginType.id) (order: \(pluginType.order))")
                }
            }
        }

        let sortedPluginClassNames = pluginClassNames.sorted()
        
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
            let pluginType = type(of: plugin)
            if let providerType = plugin.llmProviderType() {
                providerTypes.append(providerType)
                providerDiagnostics.append("\(pluginType.id)->\(providerType.id)")
            } else {
                providerDiagnostics.append("\(pluginType.id)->nil")
            }
        }
        self.discoveredLLMProviderTypes = providerTypes

        let discoveredProviderIDs = providerTypes.map { $0.id }

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
    
    /// 检查插件是否被用户启用
    ///
    /// 判断逻辑：
    /// 1. 如果插件不可配置（`isConfigurable = false`），始终返回 true
    /// 2. 如果插件可配置，从用户设置中读取启用状态；
    ///    若用户未手动配置过，则回退到插件的 `enable` 静态属性作为默认值
    ///
    /// - Parameter plugin: 要检查的插件
    /// - Returns: 如果插件被启用则返回 true
    func isPluginEnabled(_ plugin: any SuperPlugin) -> Bool {
        let pluginType = type(of: plugin)
        
        // 如果不允许用户切换，则始终启用
        if !pluginType.isConfigurable {
            return true
        }
        
        // 检查用户配置；未配置时使用插件的 enable 静态属性作为默认值
        let pluginId = plugin.instanceLabel
        return settingsStore.isPluginEnabled(pluginId, defaultEnabled: pluginType.enable)
    }

    /// 获取所有插件的根视图包裹
    ///
    /// 将所有插件提供的根视图包装器依次应用于内容视图。
    /// 包装顺序与插件的 `order` 顺序一致。
    ///
    /// - Parameter content: 原始内容视图
    /// - Returns: 经过所有插件依次包裹后的视图
    func getRootViewWrapper<Content: View>(@ViewBuilder content: () -> Content) -> AnyView {
        var wrapped: AnyView = AnyView(content())

        for plugin in plugins {
            wrapped = plugin.wrapRoot(wrapped)
        }

        return wrapped
    }

    /// 获取右侧栏根视图包裹
    ///
    /// 将所有启用插件提供的右侧栏包装器依次应用于右侧栏内容。
    /// 用于右侧栏范围内的拖放检测、浮层提示等局部能力。
    func getRightSidebarRootWrapper<Content: View>(
        activeIcon: String?,
        @ViewBuilder content: () -> Content
    ) -> AnyView {
        var wrapped: AnyView = AnyView(content())

        for plugin in plugins where isPluginEnabled(plugin) {
            wrapped = plugin.wrapRightSidebarRoot(wrapped, activeIcon: activeIcon)
        }

        return wrapped
    }

    /// 获取所有插件的工具栏前导视图
    ///
    /// 收集所有启用插件提供的工具栏左侧视图。
    /// 这些视图将在工具栏左侧水平排列显示。
    ///
    /// - Returns: 工具栏前导视图数组
    func getToolbarLeadingViews() -> [AnyView] {
        let activeIcon = activePanelIcon
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addToolBarLeadingView(activeIcon: activeIcon) }
    }

    /// 获取所有插件的工具栏中间视图
    ///
    /// 收集所有启用插件提供的工具栏中间视图。
    /// 这些视图将在工具栏中间位置水平排列显示。
    ///
    /// - Returns: 工具栏中间视图数组
    func getToolbarCenterViews() -> [AnyView] {
        let activeIcon = activePanelIcon
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addToolBarCenterView(activeIcon: activeIcon) }
    }

    /// 获取所有插件的工具栏右侧视图
    ///
    /// 收集所有启用插件提供的工具栏右侧视图。
    /// 这些视图将在工具栏右侧水平排列显示。
    ///
    /// - Returns: 工具栏右侧视图数组
    func getToolbarTrailingViews() -> [AnyView] {
        let activeIcon = activePanelIcon
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addToolBarTrailingView(activeIcon: activeIcon) }
    }

    /// 获取所有面板图标项（用于左侧活动栏）
    ///
    /// 仅收集各插件通过 `addPanelIcon()` 提供的图标信息，
    /// 不触发 `addPanelView(activeIcon:)`。用于渲染活动栏图标按钮。
    ///
    /// 如果发现两个插件提供了相同的 icon，会触发 fatalError。
    func getPanelIconItems() -> [PanelIconItem] {
        if let panelIconItemsCache {
            return panelIconItemsCache
        }
        let enabledPlugins = plugins.filter { isPluginEnabled($0) }
        var items: [PanelIconItem] = []
        var seenIcons: [String: String] = [:]  // icon -> plugin id

        for plugin in enabledPlugins {
            guard let icon = plugin.addPanelIcon() else { continue }
            let pluginType = type(of: plugin)
            let pluginId = plugin.instanceLabel

            if let existingPluginId = seenIcons[icon] {
                fatalError(
                    "[AppPluginVM] Duplicate panel icon \"\(icon)\" detected: " +
                    "\(existingPluginId) and \(pluginId) both provide the same icon. " +
                    "Each plugin must provide a unique icon via addPanelIcon()."
                )
            }
            seenIcons[icon] = pluginId
            items.append(PanelIconItem(
                id: pluginId,
                title: pluginType.displayName,
                icon: icon
            ))
        }
        panelIconItemsCache = items
        return items
    }

    /// 当前激活的活动栏图标是否在 `allowedIcons` 中。
    func isActivePanelIcon(in allowedIcons: [String]) -> Bool {
        guard let activePanelIcon else { return false }
        return allowedIcons.contains(activePanelIcon)
    }

    /// 获取当前激活插件的 PanelItem
    ///
    /// 根据 `activePanelIcon` 查找匹配的插件，调用其 `addPanelView(activeIcon:)` 获取视图。
    /// 只会有一个插件匹配并返回面板视图。
    func getActivePanelItem() -> PanelItem? {
        guard let activeIcon = activePanelIcon else { return nil }
        
        for plugin in plugins where isPluginEnabled(plugin) {
            guard let pluginIcon = plugin.addPanelIcon() else { continue }
            guard pluginIcon == activeIcon else { continue }
            
            guard let view = plugin.addPanelView(activeIcon: activeIcon) else { continue }
            let pluginType = type(of: plugin)
            let item = PanelItem(
                id: plugin.instanceLabel,
                title: pluginType.displayName,
                icon: pluginIcon,
                view: view
            )
            return item
        }
        return nil
    }

    /// 获取当前激活插件的所有 Panel Header 视图
    ///
    /// 收集所有启用插件通过 `addPanelHeaderView(activeIcon:)` 提供的 header 视图，
    /// 按插件 `order` 升序垂直堆叠（order 小的在上，大的在下）。
    ///
    /// - Returns: Panel Header 视图数组
    func getActivePanelHeaderViews() -> [AnyView] {
        let activeIcon = activePanelIcon
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addPanelHeaderView(activeIcon: activeIcon) }
    }

    /// 获取所有插件提供的底部面板标签页
    ///
    /// 收集所有启用插件通过 `addBottomPanelTabs()` 提供的标签页，
    /// 按 priority 升序排列。
    func getBottomPanelTabs() -> [BottomPanelTab] {
        let activeIcon = activePanelIcon
        let key = activeIconCacheKey()
        if let cached = bottomPanelTabsCache, cached.key == key {
            return cached.tabs
        }
        let tabs = plugins
            .filter { isPluginEnabled($0) }
            .flatMap { $0.addBottomPanelTabs(activeIcon: activeIcon) }
            .sorted { $0.priority < $1.priority }
        bottomPanelTabsCache = (key, tabs)
        return tabs
    }

    /// 获取指定底部面板 Tab 对应的内容视图
    func getBottomPanelContentView(tabId: String) -> AnyView? {
        let activeIcon = activePanelIcon
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addBottomPanelContentView(tabId: tabId, activeIcon: activeIcon) }
            .first
    }

    /// 当前是否有底部面板标签页
    func hasBottomPanelTabs() -> Bool {
        !getBottomPanelTabs().isEmpty
    }

    /// 当前是否有面板视图
    ///
    /// 用于布局决策：有面板时使用中间栏 + 右侧栏分栏，无时仅显示右侧栏。
    func hasPanels() -> Bool {
        plugins
            .filter { isPluginEnabled($0) }
            .contains { plugin -> Bool in
                guard let icon = plugin.addPanelIcon() else { return false }
                return plugin.addPanelView(activeIcon: icon) != nil
            }
    }

    /// 聚合所有插件提供的 Rail 标签页
    ///
    /// 收集所有启用插件通过 `addRailTabs()` 提供的标签页，
    /// 按 priority 升序排列。
    func getRailTabs() -> [RailTab] {
        let activeIcon = activePanelIcon
        let key = activeIconCacheKey()
        if let cached = railTabsCache, cached.key == key {
            return cached.tabs
        }
        let tabs = plugins
            .filter { isPluginEnabled($0) }
            .flatMap { $0.addRailTabs(activeIcon: activeIcon) }
            .sorted { $0.priority < $1.priority }
        railTabsCache = (key, tabs)
        return tabs
    }

    /// 获取指定 Rail tab 对应的内容视图
    func getRailContentView(tabId: String) -> AnyView? {
        let activeIcon = activePanelIcon
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addRailContentView(tabId: tabId, activeIcon: activeIcon) }
            .first
    }

    /// 当前是否有 Rail 标签页
    func hasRailTabs() -> Bool {
        !getRailTabs().isEmpty
    }

    /// 获取所有插件提供的右侧栏 Section 视图
    ///
    /// 收集所有启用插件通过 `addSidebarSections()` 提供的 Section 视图，
    /// 按插件 `order` 升序扁平化排列（order 小的在上，大的在下）。
    /// 内核将这些 Section 使用 VStack 垂直堆叠在右侧栏中。
    ///
    /// - Returns: 右侧栏 Section 视图数组
    func getSidebarSections() -> [AnyView] {
        let activeIcon = activePanelIcon
        return plugins
            .filter { isPluginEnabled($0) }
            .flatMap { $0.addSidebarSections(activeIcon: activeIcon) }
    }

    /// 当前是否有右侧栏 Section 视图
    func hasSidebars() -> Bool {
        !getSidebarSections().isEmpty
    }

    // MARK: - Sidebar Toolbar Items

    /// 聚合所有插件提供的右侧栏底部工具栏左侧项
    ///
    /// 收集所有启用插件通过 `addSidebarLeadingToolbarItems()` 提供的工具栏项，
    /// 按 `priority` 升序排列。
    func getSidebarLeadingToolbarItems() -> [SidebarToolbarItem] {
        let activeIcon = activePanelIcon
        let key = activeIconCacheKey()
        if let cached = sidebarLeadingToolbarItemsCache, cached.key == key {
            return cached.items
        }
        let items = plugins
            .filter { isPluginEnabled($0) }
            .flatMap { $0.addSidebarLeadingToolbarItems(activeIcon: activeIcon) }
            .sorted { $0.priority < $1.priority }
        sidebarLeadingToolbarItemsCache = (key, items)
        return items
    }

    /// 聚合所有插件提供的右侧栏底部工具栏右侧项
    ///
    /// 收集所有启用插件通过 `addSidebarTrailingToolbarItems()` 提供的工具栏项，
    /// 按 `priority` 升序排列。
    func getSidebarTrailingToolbarItems() -> [SidebarToolbarItem] {
        let activeIcon = activePanelIcon
        let key = activeIconCacheKey()
        if let cached = sidebarTrailingToolbarItemsCache, cached.key == key {
            return cached.items
        }
        let items = plugins
            .filter { isPluginEnabled($0) }
            .flatMap { $0.addSidebarTrailingToolbarItems(activeIcon: activeIcon) }
            .sorted { $0.priority < $1.priority }
        sidebarTrailingToolbarItemsCache = (key, items)
        return items
    }

    /// 获取指定右侧栏工具栏项对应的自定义按钮视图
    func getSidebarToolbarItemView(itemId: String) -> AnyView? {
        let activeIcon = activePanelIcon
        return plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addSidebarToolbarItemView(itemId: itemId, activeIcon: activeIcon) }
            .first
    }

    /// 当前是否有右侧栏工具栏项
    func hasSidebarToolbarItems() -> Bool {
        !getSidebarLeadingToolbarItems().isEmpty || !getSidebarTrailingToolbarItems().isEmpty
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

        if Self.verbose {
            let pluginNames = plugins.map { String(describing: type(of: $0)) }
            let enabledNames = plugins.filter { isPluginEnabled($0) }.map { String(describing: type(of: $0)) }
            AppLogger.core.info("\(self.t) getStatusBarLeadingViews: 所有插件=\(pluginNames), 启用的插件=\(enabledNames), 状态栏左侧视图数量=\(views.count)")
        }

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

        if Self.verbose {
            let pluginNames = plugins.map { String(describing: type(of: $0)) }
            let enabledNames = plugins.filter { isPluginEnabled($0) }.map { String(describing: type(of: $0)) }
            AppLogger.core.info("\(self.t) getStatusBarCenterViews: 所有插件=\(pluginNames), 启用的插件=\(enabledNames), 状态栏中间视图数量=\(views.count)")
        }

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

        if Self.verbose {
            let pluginNames = plugins.map { String(describing: type(of: $0)) }
            let enabledNames = plugins.filter { isPluginEnabled($0) }.map { String(describing: type(of: $0)) }
            AppLogger.core.info("\(self.t) getStatusBarTrailingViews: 所有插件=\(pluginNames), 启用的插件=\(enabledNames), 状态栏右侧视图数量=\(views.count)")
        }

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
                let type = type(of: plugin)
                return (type.id, type.displayName, type.iconName, view)
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
        if Self.verbose {
            AppLogger.core.info("\(self.t)📦 Registered \(self.discoveredLLMProviderTypes.count) LLM providers from plugins.")
        }
    }

    // MARK: - Category Aggregation

    /// 获取按分类分组的可配置插件列表
    ///
    /// 将所有可配置插件按 ``PluginCategory`` 分组，
    /// 分类按 ``PluginCategory/sortOrder`` 升序排列，
    /// 分类内插件按 ``SuperPlugin/order`` 升序排列。
    func getConfigurablePluginsGroupedByCategory() -> [(category: PluginCategory, plugins: [any SuperPlugin])] {
        let configurable = plugins.filter { type(of: $0).isConfigurable }
        let grouped = Dictionary(grouping: configurable) { type(of: $0).category }
        return grouped
            .map { (category: $0.key, plugins: $0.value.sorted { type(of: $0).order < type(of: $1).order }) }
            .sorted { $0.category.sortOrder < $1.category.sortOrder }
    }

    /// 获取所有启用插件提供的主题贡献（按插件 `order` 稳定排序，并写入 ``ThemeSortKey``）
    @MainActor
    func getThemeContributions() -> [LumiUIThemeContribution] {
        let enabledPlugins = plugins.filter { isPluginEnabled($0) }
        var merged: [(pluginOrder: Int, item: LumiUIThemeContribution)] = []

        for plugin in enabledPlugins {
            let pluginOrder = type(of: plugin).order
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
