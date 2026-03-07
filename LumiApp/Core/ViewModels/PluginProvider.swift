import AppKit
import MagicKit
import Foundation
import OSLog
import SwiftUI
import ObjectiveC.runtime
import Combine

/// 插件提供者，管理插件的生命周期和 UI 贡献
@MainActor
final class PluginProvider: ObservableObject, SuperLog {
    /// 全局单例
    static let shared = PluginProvider()

    /// 日志标识符
    nonisolated static let emoji = "🔌"

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 已加载的插件列表
    @Published private(set) var plugins: [any SuperPlugin] = []
    
    /// 插件是否已加载完成
    @Published private(set) var isLoaded: Bool = false

    /// 当前选中的应用模式
//    @Published var selectedMode: AppMode = .app

    /// 插件设置存储
    private let settingsStore: PluginSettingsStore
    
    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    /// 初始化插件提供者（自动发现并注册所有插件）
    private init(settingsStore: PluginSettingsStore = PluginSettingsStore.shared, autoDiscover: Bool = true) {
        self.settingsStore = settingsStore

        if autoDiscover {
            autoDiscoverAndRegisterPlugins()
        }

        // 订阅设置变化，当设置改变时触发 UI 更新
        settingsStore.$settings
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // 监听文件选择变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFileSelectionChanged),
            name: NSNotification.Name("AgentProviderFileSelectionChanged"),
            object: nil
        )
    }

    /// 处理文件选择变化通知
    @objc private func handleFileSelectionChanged(_ notification: Notification) {
        objectWillChange.send()
    }

    /// 自动发现并注册所有插件
    private func autoDiscoverAndRegisterPlugins() {
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
                    os_log("\(self.t)🔍 Discovered plugin: \(pluginType.id) (order: \(pluginType.order))")
                }
            }
        }
        
        // 按顺序排序
        discoveredItems.sort { $0.order < $1.order }
        
        // 更新插件列表
        let sortedPlugins = discoveredItems.map { $0.instance }
        self.plugins = sortedPlugins
        self.isLoaded = true
        
        // 调用生命周期钩子
        for plugin in sortedPlugins {
            plugin.onRegister()
            // 如果插件被启用，调用 onEnable
            if self.isPluginEnabled(plugin) {
                plugin.onEnable()
            }
        }
        
        // 发送通知
        NotificationCenter.default.post(
            name: NSNotification.Name("PluginsDidLoad"),
            object: self
        )
        
        if Self.verbose {
            os_log("\(self.t)✅ Auto-discovery complete. Loaded \(sortedPlugins.count) plugins.")
        }
    }
    
    /// 创建 actor 实例的辅助函数
    /// 由于 actor 的特殊性，我们需要使用 Objective-C Runtime 来创建实例
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
    /// - Parameter content: 原始内容视图
    /// - Returns: 经过所有插件依次包裹后的视图
    func getRootViewWrapper<Content: View>(@ViewBuilder content: () -> Content) -> AnyView {
        var wrapped: AnyView = AnyView(content())

        for plugin in plugins {
            wrapped = plugin.wrapRoot(wrapped)
        }

        return wrapped
    }

    /// 获取所有插件的工具栏右侧视图
    /// - Returns: 工具栏右侧视图数组
    func getToolbarTrailingViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addToolBarTrailingView() }
    }

    /// 获取所有插件的详情视图
    /// - Returns: 详情视图数组
    func getDetailViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addDetailView() }
    }

    /// 获取所有插件提供的状态栏弹窗视图
    /// - Returns: 状态栏弹窗视图数组
    func getStatusBarPopupViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addStatusBarPopupView() }
    }

    /// 获取所有插件提供的状态栏内容视图
    /// - Returns: 状态栏内容视图数组
    func getStatusBarContentViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addStatusBarContentView() }
    }

    /// 获取所有插件提供的侧边栏视图（用于 Agent 模式）
    /// - Returns: 侧边栏视图数组，多个插件的侧边栏会从上到下垂直堆叠显示
    func getSidebarViews() -> [AnyView] {
        let views = plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addSidebarView() }

        if Self.verbose {
            let pluginNames = plugins.map { String(describing: type(of: $0)) }
            let enabledNames = plugins.filter { isPluginEnabled($0) }.map { String(describing: type(of: $0)) }
            os_log("\(self.t) getSidebarViews: 所有插件=\(pluginNames), 启用的插件=\(enabledNames), 侧边栏视图数量=\(views.count)")
        }

        return views
    }

    /// 获取所有插件提供的中间栏视图（用于 Agent 模式）
    /// 中间栏位于侧边栏和详情栏之间，用于展示文件预览等内容
    /// - Returns: 中间栏视图数组，多个插件的中间栏会从上到下垂直堆叠显示
    func getMiddleViews() -> [AnyView] {
        let views = plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addMiddleView() }

        if Self.verbose {
            let pluginNames = plugins.map { String(describing: type(of: $0)) }
            let enabledNames = plugins.filter { isPluginEnabled($0) }.map { String(describing: type(of: $0)) }
            os_log("\(self.t) getMiddleViews: 所有插件=\(pluginNames), 启用的插件=\(enabledNames), 中间栏视图数量=\(views.count)")
        }

        return views
    }

    /// 获取所有插件提供的详情栏头部视图（用于 Agent 模式）
    /// 详情栏头部位于详情栏顶部，用于显示聊天头部等信息
    /// - Returns: 详情栏头部视图数组，多个插件的头部视图会从上到下垂直堆叠显示
    func getDetailHeaderViews() -> [AnyView] {
        let views = plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addDetailHeaderView() }

        if Self.verbose {
            let pluginNames = plugins.map { String(describing: type(of: $0)) }
            let enabledNames = plugins.filter { isPluginEnabled($0) }.map { String(describing: type(of: $0)) }
            os_log("\(self.t) getDetailHeaderViews: 所有插件=\(pluginNames), 启用的插件=\(enabledNames), 详情栏头部视图数量=\(views.count)")
        }

        return views
    }

    /// 获取所有插件提供的详情栏中间视图（用于 Agent 模式）
    /// 详情栏中间位于详情栏中部，用于显示消息列表等内容
    /// - Returns: 详情栏中间视图数组，多个插件的中间视图会从上到下垂直堆叠显示
    func getDetailMiddleViews() -> [AnyView] {
        let views = plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addDetailMiddleView() }

        if Self.verbose {
            let pluginNames = plugins.map { String(describing: type(of: $0)) }
            let enabledNames = plugins.filter { isPluginEnabled($0) }.map { String(describing: type(of: $0)) }
            os_log("\(self.t) getDetailMiddleViews: 所有插件=\(pluginNames), 启用的插件=\(enabledNames), 详情栏中间视图数量=\(views.count)")
        }

        return views
    }

    /// 获取所有插件提供的详情栏底部视图（用于 Agent 模式）
    /// 详情栏底部位于详情栏底部，用于显示输入区域等内容
    /// - Returns: 详情栏底部视图数组，多个插件的底部视图会从上到下垂直堆叠显示
    func getDetailBottomViews() -> [AnyView] {
        let views = plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addDetailBottomView() }

        if Self.verbose {
            let pluginNames = plugins.map { String(describing: type(of: $0)) }
            let enabledNames = plugins.filter { isPluginEnabled($0) }.map { String(describing: type(of: $0)) }
            os_log("\(self.t) getDetailBottomViews: 所有插件=\(pluginNames), 启用的插件=\(enabledNames), 详情栏底部视图数量=\(views.count)")
        }

        return views
    }

    /// 获取所有插件的设置视图信息
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

    /// 获取所有插件提供的导航入口
    /// - Returns: 导航入口数组
    func getNavigationEntries() -> [NavigationEntry] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addNavigationEntries() }
            .flatMap { $0 }
    }

    /// 获取指定模式下的导航入口
    /// - Parameter mode: 应用模式
    /// - Returns: 导航入口数组
    func getNavigationEntries(for mode: AppMode) -> [NavigationEntry] {
        getNavigationEntries().filter { $0.mode == mode }
    }

    /// 重新加载插件
    func reloadPlugins() {
        isLoaded = false
        autoDiscoverAndRegisterPlugins()
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
