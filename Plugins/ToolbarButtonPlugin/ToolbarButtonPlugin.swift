import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 工具栏按钮插件：在工具栏显示可点击的按钮
class ToolbarButtonPlugin: NSObject, SuperPlugin, PluginRegistrant, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "🔘"

    /// 是否启用该插件
    static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    static var id: String = "ToolbarButtonPlugin"

    /// 插件显示名称
    static var displayName: String = "工具栏按钮"

    /// 插件功能描述
    static var description: String = "在工具栏右侧显示可点击的按钮"

    /// 插件图标名称
    static var iconName: String = "star"

    /// 是否可配置
    static var isConfigurable: Bool = true

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    var instanceLabel: String {
        Self.id
    }

    /// 插件单例实例
    static let shared = ToolbarButtonPlugin()

    /// 私有初始化方法
    private override init() {}

    /// 检查插件是否被用户启用
    private var isUserEnabled: Bool {
        PluginSettingsStore.shared.isPluginEnabled(Self.id)
    }

    // MARK: - UI Contributions

    /// 添加工具栏前导视图
    /// - Returns: 工具栏前导视图
    func addToolBarLeadingView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return nil
    }

    /// 添加工具栏右侧视图
    /// - Returns: 工具栏右侧视图
    func addToolBarTrailingView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return AnyView(ToolbarActionButton())
    }

    /// 添加状态栏左侧视图
    /// - Returns: 状态栏左侧视图
    func addStatusBarLeadingView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return nil
    }

    /// 添加状态栏右侧视图
    /// - Returns: 状态栏右侧视图
    func addStatusBarTrailingView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return nil
    }

    /// 添加详情视图
    /// - Returns: 详情视图
    func addDetailView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return nil
    }

    /// 添加列表视图
    /// - Parameters:
    ///   - tab: 标签页
    ///   - project: 项目对象
    /// - Returns: 列表视图
    func addListView(tab: String, project: Project?) -> AnyView? {
        guard isUserEnabled else { return nil }
        return nil
    }

    /// 添加侧边栏视图
    /// - Returns: 要添加到侧边栏的视图，如果不需要则返回nil
    func addSidebarView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return nil
    }
}

// MARK: - PluginRegistrant

extension ToolbarButtonPlugin {
    /// 注册插件到插件注册表
    static func register() {
        guard enable else { return }

        Task {
            if Self.verbose {
                os_log("\(Self.t) 🚀 Register ToolbarButtonPlugin")
            }

            await PluginRegistry.shared.register(id: id, order: 4) {
                ToolbarButtonPlugin.shared
            }
        }
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
