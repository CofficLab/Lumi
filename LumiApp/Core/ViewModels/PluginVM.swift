import AppKit
import MagicKit
import Foundation
import SwiftUI
import ObjectiveC.runtime
import Combine

/// 插件 VM，管理插件的生命周期和 UI 贡献
///
/// PluginVM 是 Lumi 插件系统的核心管理器，负责：
/// - 自动发现并注册所有插件
/// - 管理插件的生命周期（注册、启用、禁用）
/// - 聚合所有插件提供的 UI 扩展点
/// - 处理插件设置的持久化
///
/// ## 插件发现机制
///
/// PluginVM 使用 Objective-C Runtime 扫描所有以 "Lumi." 开头
/// 且以 "Plugin" 结尾的类，自动创建实例并注册。
/// 插件按 `order` 属性排序，确保按正确顺序加载。
///
/// ## 线程安全
///
/// ⚠️ 注意：此类标记为 `@MainActor`，所有成员访问都必须在主线程。
/// 这确保了 UI 相关的操作（如插件注册、视图获取）的线程安全性。
///
/// ## 使用示例
///
/// ```swift
/// // 获取面板视图
/// let panels = PluginVM.shared.getPanelItems()
///
/// // 检查插件是否启用
/// let isEnabled = PluginVM.shared.isPluginEnabled(somePlugin)
/// ```
@MainActor
final class PluginVM: ObservableObject, SuperLog {
    /// 面板视图项（用于左侧活动栏注册的统一入口）
    struct PanelItem: Identifiable, Equatable {
        let id: String
        let title: String
        let icon: String
        let view: AnyView
        /// 该面板是否需要右侧栏
        let panelNeedsSidebar: Bool
        
        static func == (lhs: PanelItem, rhs: PanelItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// 全局单例
    ///
    /// 整个应用共享同一个 PluginVM 实例。
    /// 使用 `shared` 属性访问全局实例。
    static let shared = PluginVM()

    /// 日志标识符
    ///
    /// 用于日志输出的前缀标识。
    nonisolated static let emoji = "🔌"

    /// 是否启用详细日志输出
    nonisolated static let verbose: Bool = false
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
    private let settingsStore: PluginSettingsVM
    
    /// Combine 订阅集合
    ///
    /// 存储所有 Combine 订阅，用于在 deinit 时取消。
    /// 防止内存泄漏。
    private var cancellables = Set<AnyCancellable>()
    private var sidebarViewsCache: [AnyView]?
    private var sidebarViewsCacheKey: String?
    private var rightSidebarViewsCache: [AnyView]?

    // MARK: - Tools Cache

    private var cachedAgentTools: [AgentTool]?
    private var cachedAgentToolFactories: [AnyAgentToolFactory]?
    private var cachedSendMiddlewares: [SendMiddleware]?
    /// 初始化插件 VM
    ///
    /// - Parameters:
    ///   - settingsStore: 插件设置存储实例，默认使用单例
    ///   - autoDiscover: 是否自动发现插件，默认为 true
    ///
    /// 如果 `autoDiscover` 为 true，会立即扫描并注册所有插件。
    /// 设为 false 可以延迟加载，常用于测试场景。
    private init(settingsStore: PluginSettingsVM = PluginSettingsVM.shared, autoDiscover: Bool = true) {
        self.settingsStore = settingsStore

        if autoDiscover {
            autoDiscoverAndRegisterPlugins()
        }

        // 订阅设置变化，当设置改变时触发 UI 更新
        settingsStore.$settings
            .sink { [weak self] _ in
                self?.sidebarViewsCache = nil
                self?.sidebarViewsCacheKey = nil
                self?.rightSidebarViewsCache = nil
                self?.cachedAgentTools = nil
                self?.cachedAgentToolFactories = nil
                self?.cachedSendMiddlewares = nil
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // 监听文件选择变化通知
        // 用于在 Agent 模式中当用户选择不同文件时刷新相关插件的 UI
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFileSelectionChanged),
            name: .fileSelectionChanged,
            object: nil
        )
    }

    // MARK: - Agent Tools Aggregation

    func getAgentTools() -> [AgentTool] {
        if let cachedAgentTools {
            return cachedAgentTools
        }

        let enabledPlugins = plugins.filter { isPluginEnabled($0) }
        var tools: [(pluginOrder: Int, tool: AgentTool)] = []

        for plugin in enabledPlugins {
            let pluginOrder = type(of: plugin).order
            let pluginTools = plugin.agentTools()
            for t in pluginTools {
                tools.append((pluginOrder: pluginOrder, tool: t))
            }
        }

        let sorted = tools.sorted { a, b in
            if a.pluginOrder != b.pluginOrder { return a.pluginOrder < b.pluginOrder }
            return a.tool.name < b.tool.name
        }.map(\.tool)

        cachedAgentTools = sorted
        return sorted
    }

    func getAgentToolFactories() -> [AnyAgentToolFactory] {
        if let cachedAgentToolFactories {
            return cachedAgentToolFactories
        }

        let enabledPlugins = plugins.filter { isPluginEnabled($0) }
        var factories: [(pluginOrder: Int, f: AnyAgentToolFactory)] = []

        for plugin in enabledPlugins {
            let pluginOrder = type(of: plugin).order
            let fs = plugin.agentToolFactories()
            for f in fs {
                factories.append((pluginOrder: pluginOrder, f: f))
            }
        }

        let sorted = factories.sorted { a, b in
            if a.pluginOrder != b.pluginOrder { return a.pluginOrder < b.pluginOrder }
            if a.f.order != b.f.order { return a.f.order < b.f.order }
            return a.f.id < b.f.id
        }.map(\.f)

        cachedAgentToolFactories = sorted
        return sorted
    }

    // MARK: - Send Middleware

    func getSendMiddlewares() -> [SendMiddleware] {
        if let cachedSendMiddlewares {
            return cachedSendMiddlewares
        }

        let enabledPlugins = plugins.filter { isPluginEnabled($0) }
        var items: [(pluginOrder: Int, mwOrder: Int, middleware: SendMiddleware)] = []

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

        cachedSendMiddlewares = sorted
        return sorted
    }

    /// 析构函数，清理资源
    ///
    /// 移除所有 NotificationCenter 观察者，防止内存泄漏。
    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: .fileSelectionChanged,
            object: nil
        )
    }

    /// 处理文件选择变化通知
    ///
    /// 当 Agent 模式中的文件选择改变时调用。
    /// 触发 objectWillChange 以刷新 UI。
    ///
    /// - Parameter notification: 通知对象，包含文件选择信息
    @objc private func handleFileSelectionChanged(_ notification: Notification) {
        sidebarViewsCache = nil
        sidebarViewsCacheKey = nil
        rightSidebarViewsCache = nil
        objectWillChange.send()
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
        sidebarViewsCache = nil
        sidebarViewsCacheKey = nil
        rightSidebarViewsCache = nil
        cachedAgentTools = nil
        cachedAgentToolFactories = nil
        cachedSendMiddlewares = nil

        var count: UInt32 = 0
        guard let classList = objc_copyClassList(&count) else { return }
        defer { free(UnsafeMutableRawPointer(classList)) }
        
        let classes = UnsafeBufferPointer(start: classList, count: Int(count))
        // 临时存储，包含 (实例，类名，顺序)
        var discoveredItems: [(instance: any SuperPlugin, className: String, order: Int)] = []
        
        for i in 0 ..< classes.count {
            let cls: AnyClass = classes[i]
            let className = NSStringFromClass(cls)
            
            // 筛选条件：Lumi 命名空间且以 Plugin 结尾的类
            guard className.hasPrefix("Lumi."), className.hasSuffix("Plugin") else { continue }
            
            // 尝试创建 Actor 实例
            guard let instance = createActorInstance(cls: cls) as? any SuperPlugin else {
                continue
            }
            
            // 检查插件是否启用
            let pluginType = type(of: instance)
            if pluginType.enable {
                discoveredItems.append((instance, className, pluginType.order))
                if Self.verbose {
                    AppLogger.core.info("\(self.t)🔍 Discovered plugin: \(pluginType.id) (order: \(pluginType.order))")
                }
            }
        }
        
        // 按 order 升序排序，确保核心插件先加载
        discoveredItems.sort { $0.order < $1.order }
        
        // 更新插件列表
        let sortedPlugins = discoveredItems.map { $0.instance }
        self.plugins = sortedPlugins
        self.isLoaded = true

        // 插件已更新，清空聚合缓存，避免在插件加载前被读取后永久缓存为空。
        cachedAgentTools = nil
        cachedAgentToolFactories = nil
        cachedSendMiddlewares = nil

        // 调用生命周期钩子
        for plugin in sortedPlugins {
            plugin.onRegister()
            // 如果插件被启用，调用 onEnable
            if self.isPluginEnabled(plugin) {
                plugin.onEnable()
            }
        }
        
        // 发送通知，告知其他组件插件加载完成
        NotificationCenter.postPluginsDidLoad()
        
        if Self.verbose {
            AppLogger.core.info("\(self.t)✅ Auto-discovery complete. Loaded \(sortedPlugins.count) plugins.")
        }
    }
    
    /// 创建 actor 实例的辅助函数
    ///
    /// 由于 Actor 的特殊性，不能使用普通的 `new` 或 `init()` 创建实例。
    /// 需要使用 Objective-C Runtime 的 alloc/init 方法。
    ///
    /// - Parameter cls: 要实例化的类
    /// - Returns: 插件实例，如果创建失败则返回 nil
    private func createActorInstance(cls: AnyClass) -> AnyObject? {
        // 尝试获取 alloc 方法
        let allocSelector = NSSelectorFromString("alloc")
        guard let allocMethod = class_getClassMethod(cls, allocSelector) else {
            return nil
        }
        
        // 调用 alloc
        typealias AllocMethod = @convention(c) (AnyClass, Selector) -> AnyObject?
        let allocImpl = unsafeBitCast(method_getImplementation(allocMethod), to: AllocMethod.self)
        guard let instance = allocImpl(cls, allocSelector) else {
            return nil
        }
        
        // 尝试获取 init() 方法
        let initSelector = NSSelectorFromString("init")
        guard let initMethod = class_getInstanceMethod(cls, initSelector) else {
            // 如果没有 init 方法，直接返回 alloc 的实例（虽然这通常不应该发生）
            return instance
        }
        
        // 调用 init
        typealias InitMethod = @convention(c) (AnyObject, Selector) -> AnyObject?
        let initImpl = unsafeBitCast(method_getImplementation(initMethod), to: InitMethod.self)
        
        return initImpl(instance, initSelector) ?? instance
    }

    /// 检查插件是否被用户启用
    ///
    /// 判断逻辑：
    /// 1. 如果插件不可配置（`isConfigurable = false`），始终返回 true
    /// 2. 如果插件可配置，从用户设置中读取启用状态
    ///
    /// - Parameter plugin: 要检查的插件
    /// - Returns: 如果插件被启用则返回 true
    func isPluginEnabled(_ plugin: any SuperPlugin) -> Bool {
        let pluginType = type(of: plugin)
        
        // 如果不允许用户切换，则始终启用
        if !pluginType.isConfigurable {
            return true
        }
        
        // 检查用户配置
        let pluginId = plugin.instanceLabel
        return settingsStore.isPluginEnabled(pluginId)
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

    /// 获取所有插件的工具栏前导视图
    ///
    /// 收集所有启用插件提供的工具栏左侧视图。
    /// 这些视图将在工具栏左侧水平排列显示。
    ///
    /// - Returns: 工具栏前导视图数组
    func getToolbarLeadingViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addToolBarLeadingView() }
    }

    /// 获取所有插件的工具栏中间视图
    ///
    /// 收集所有启用插件提供的工具栏中间视图。
    /// 这些视图将在工具栏中间位置水平排列显示。
    ///
    /// - Returns: 工具栏中间视图数组
    func getToolbarCenterViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addToolBarCenterView() }
    }

    /// 获取所有插件的工具栏右侧视图
    ///
    /// 收集所有启用插件提供的工具栏右侧视图。
    /// 这些视图将在工具栏右侧水平排列显示。
    ///
    /// - Returns: 工具栏右侧视图数组
    func getToolbarTrailingViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addToolBarTrailingView() }
    }

    /// 获取所有面板视图项（用于左侧活动栏）
    ///
    /// 每个提供 `addPanelView()` 的插件都会生成一个活动栏图标入口。
    func getPanelItems() -> [PanelItem] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { plugin -> PanelItem? in
                guard let view = plugin.addPanelView() else { return nil }
                let pluginType = type(of: plugin)
                return PanelItem(
                    id: plugin.instanceLabel,
                    title: pluginType.displayName,
                    icon: pluginType.iconName,
                    view: view,
                    panelNeedsSidebar: plugin.panelNeedsSidebar
                )
            }
    }

    /// 当前是否有面板视图
    ///
    /// 用于布局决策：有面板时使用中间栏 + 右侧栏分栏，无时仅显示右侧栏。
    func hasPanels() -> Bool {
        plugins
            .filter { isPluginEnabled($0) }
            .contains { $0.addPanelView() != nil }
    }

    /// 获取所有插件提供的右侧栏视图
    ///
    /// 收集所有启用插件提供的右侧栏视图。
    /// 多个右侧栏会水平堆叠，按插件 order 升序排列。
    ///
    /// - Returns: 右侧栏视图数组
    func getSidebarViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addSidebarView() }
    }

    /// 当前是否有右侧栏视图
    func hasSidebars() -> Bool {
        plugins
            .filter { isPluginEnabled($0) }
            .contains { $0.addSidebarView() != nil }
    }

    /// 获取所有插件提供的状态栏弹窗视图
    ///
    /// 收集所有启用插件提供的状态栏弹窗视图。
    /// 当用户点击菜单栏图标时显示。
    /// 每个插件可以提供多个弹窗视图，所有视图会被扁平化合并。
    ///
    /// - Returns: 状态栏弹窗视图数组
    func getStatusBarPopupViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .flatMap { $0.addStatusBarPopupViews() }
    }

    /// 获取所有插件提供的状态栏内容视图
    ///
    /// 收集所有启用插件提供的状态栏内容视图。
    /// 这些视图直接显示在菜单栏图标位置。
    ///
    /// - Returns: 状态栏内容视图数组
    func getStatusBarContentViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addStatusBarContentView() }
    }

    /// 获取所有插件提供的状态栏左侧视图（用于 Agent 模式底部状态栏）
    ///
    /// 收集所有启用插件提供的状态栏左侧视图。
    /// 状态栏位于 Agent 模式底部，用于显示状态信息、操作提示等内容。
    /// 多个插件的状态栏视图会水平排列显示在左侧。
    ///
    /// - Returns: 状态栏左侧视图数组
    func getStatusBarLeadingViews() -> [AnyView] {
        let views = plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addStatusBarLeadingView() }

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
    /// - Returns: 状态栏中间视图数组
    func getStatusBarCenterViews() -> [AnyView] {
        let views = plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addStatusBarCenterView() }

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
    /// - Returns: 状态栏右侧视图数组
    func getStatusBarTrailingViews() -> [AnyView] {
        let views = plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addStatusBarTrailingView() }

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

    /// 获取所有启用插件提供的主题贡献（按插件顺序和主题顺序稳定排序）
    @MainActor
    func getThemeContributions() -> [LumiThemeContribution] {
        let enabledPlugins = plugins.filter { isPluginEnabled($0) }
        var merged: [(pluginOrder: Int, item: LumiThemeContribution)] = []

        for plugin in enabledPlugins {
            let pluginOrder = type(of: plugin).order
            for item in plugin.addThemeContributions() {
                merged.append((pluginOrder, item))
            }
        }

        let sorted = merged.sorted { lhs, rhs in
            if lhs.pluginOrder != rhs.pluginOrder { return lhs.pluginOrder < rhs.pluginOrder }
            if lhs.item.order != rhs.item.order { return lhs.item.order < rhs.item.order }
            return lhs.item.id.localizedCaseInsensitiveCompare(rhs.item.id) == .orderedAscending
        }.map(\.item)

        var seen = Set<String>()
        var result: [LumiThemeContribution] = []
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
