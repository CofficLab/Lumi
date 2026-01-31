import AppKit
import MagicKit
import Foundation
import OSLog
import SwiftUI
import ObjectiveC.runtime
import Combine

/// 插件提供者，管理插件的生命周期和UI贡献
@MainActor
final class PluginProvider: ObservableObject, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "🔌"

    /// 是否启用详细日志输出
    nonisolated static let verbose = false

    /// 已加载的插件列表
    @Published private(set) var plugins: [any SuperPlugin] = []
    
    /// 插件是否已加载完成
    @Published private(set) var isLoaded: Bool = false

    /// 插件设置存储
    private let settingsStore = PluginSettingsStore.shared
    
    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    /// 初始化插件提供者（自动发现并注册所有插件）
    init(autoDiscover: Bool = true) {
        if autoDiscover {
            autoDiscoverAndRegisterPlugins()
        }
        
        // 订阅设置变化，当设置改变时触发 UI 更新
        settingsStore.$settings
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// 自动发现并注册所有插件
    private func autoDiscoverAndRegisterPlugins() {
        var count: UInt32 = 0
        guard let classList = objc_copyClassList(&count) else { return }
        defer { free(UnsafeMutableRawPointer(classList)) }
        
        let classes = UnsafeBufferPointer(start: classList, count: Int(count))
        // 临时存储，包含 (实例, 类名, 顺序)
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
            
            // 检查是否应该注册
            let pluginType = type(of: instance)
            if pluginType.shouldRegister {
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
            // 如果没有init方法，直接返回alloc的实例（虽然这通常不应该发生）
            return instance
        }
        
        // 调用 init
        typealias InitMethod = @convention(c) (AnyObject, Selector) -> AnyObject?
        let initImpl = unsafeBitCast(method_getImplementation(initMethod), to: InitMethod.self)
        
        return initImpl(instance, initSelector) ?? instance
    }

    /// 检查插件是否被用户启用
    /// - Parameter plugin: 要检查的插件
    /// - Returns: 如果插件被启用则返回true
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

    /// 获取所有插件的工具栏右侧视图
    /// - Returns: 工具栏右侧视图数组
    func getToolbarTrailingViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addToolBarTrailingView() }
    }

    /// 获取所有插件的状态栏左侧视图
    /// - Returns: 状态栏左侧视图数组
    func getStatusBarLeadingViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addStatusBarLeadingView() }
    }

    /// 获取所有插件的状态栏右侧视图
    /// - Returns: 状态栏右侧视图数组
    func getStatusBarTrailingViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addStatusBarTrailingView() }
    }

    /// 获取所有插件的详情视图
    /// - Returns: 详情视图数组
    func getDetailViews() -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addDetailView() }
    }

    /// 获取指定标签页和项目的列表视图
    /// - Parameters:
    ///   - tab: 标签页
    ///   - project: 项目对象
    /// - Returns: 列表视图数组
    func getListViews(for tab: String, project: Project?) -> [AnyView] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addListView(tab: tab, project: project) }
    }

    /// 获取所有插件提供的系统菜单栏菜单项
    /// - Returns: 系统菜单栏菜单项数组
    func getStatusBarMenuItems() -> [NSMenuItem] {
        plugins
            .filter { isPluginEnabled($0) }
            .compactMap { $0.addStatusBarMenuItems() }
            .flatMap { $0 }
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
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
