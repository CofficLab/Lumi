import AppKit
import MagicKit
import Foundation
import OSLog
import SwiftUI

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

    /// 初始化插件提供者（自动发现并注册所有插件）
    init(autoDiscover: Bool = true) {
        if autoDiscover {
            // 自动注册所有符合PluginRegistrant协议的插件类
            autoRegisterPlugins()

            // 加载所有已注册的插件
            loadPlugins()
        }
    }

    /// 加载所有已注册的插件
    private func loadPlugins() {
        Task {
            let loadedPlugins = await PluginRegistry.shared.buildAll()
            await MainActor.run {
                self.plugins = loadedPlugins
                self.isLoaded = true
                
                // 发送插件加载完成通知
                NotificationCenter.default.post(
                    name: NSNotification.Name("PluginsDidLoad"),
                    object: self
                )
                
                if Self.verbose {
                    os_log("\(self.t)已加载 \(loadedPlugins.count) 个插件")
                }
            }
        }
    }

    /// 获取所有插件的工具栏右侧视图
    /// - Returns: 工具栏右侧视图数组
    func getToolbarTrailingViews() -> [AnyView] {
        plugins.compactMap { $0.addToolBarTrailingView() }
    }

    /// 获取所有插件的状态栏左侧视图
    /// - Returns: 状态栏左侧视图数组
    func getStatusBarLeadingViews() -> [AnyView] {
        plugins.compactMap { $0.addStatusBarLeadingView() }
    }

    /// 获取所有插件的状态栏右侧视图
    /// - Returns: 状态栏右侧视图数组
    func getStatusBarTrailingViews() -> [AnyView] {
        plugins.compactMap { $0.addStatusBarTrailingView() }
    }

    /// 获取所有插件的详情视图
    /// - Returns: 详情视图数组
    func getDetailViews() -> [AnyView] {
        plugins.compactMap { $0.addDetailView() }
    }

    /// 获取指定标签页和项目的列表视图
    /// - Parameters:
    ///   - tab: 标签页
    ///   - project: 项目对象
    /// - Returns: 列表视图数组
    func getListViews(for tab: String, project: Project?) -> [AnyView] {
        plugins.compactMap { $0.addListView(tab: tab, project: project) }
    }

    /// 获取所有插件提供的系统菜单栏菜单项
    /// - Returns: 系统菜单栏菜单项数组
    func getStatusBarMenuItems() -> [NSMenuItem] {
        plugins.compactMap { $0.addStatusBarMenuItems() }.flatMap { $0 }
    }

    /// 重新加载插件
    func reloadPlugins() {
        isLoaded = false
        loadPlugins()
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
