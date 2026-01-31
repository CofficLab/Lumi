import Foundation
import SwiftUI

/// 插件提供者，管理插件的生命周期和UI贡献
@MainActor
final class PluginProvider: ObservableObject {
    /// 已加载的插件列表
    @Published private(set) var plugins: [any SuperPlugin] = []

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

    /// 重新加载插件
    func reloadPlugins() {
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
