import Foundation
import MagicKit
import SwiftUI
import OSLog

/// 导航插件：在侧边栏提供导航按钮
class NavigationPlugin: NSObject, SuperPlugin, PluginRegistrant, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "🧭"

    /// 是否启用该插件
    static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    static var id: String = "NavigationPlugin"

    /// 插件显示名称
    static var displayName: String = "导航"

    /// 插件功能描述
    static var description: String = "在侧边栏提供主导航按钮"

    /// 插件图标名称
    static var iconName: String = "sidebar.left"

    /// 是否可配置
    static var isConfigurable: Bool = false

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    var instanceLabel: String {
        Self.id
    }

    /// 插件单例实例
    static let shared = NavigationPlugin()

    /// 私有初始化方法
    private override init() {}

    /// 检查插件是否被用户启用
    private var isUserEnabled: Bool {
        PluginSettingsStore.shared.isPluginEnabled(Self.id)
    }

    // MARK: - UI Contributions

    /// 添加侧边栏视图
    /// - Returns: 要添加到侧边栏的视图
    func addSidebarView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return AnyView(NavigationSidebarView())
    }
}

// MARK: - PluginRegistrant

extension NavigationPlugin {
    /// 注册插件到插件注册表
    static func register() {
        guard enable else { return }

        Task {
            if Self.verbose {
                os_log("\(Self.t) 🚀 Register NavigationPlugin")
            }

            await PluginRegistry.shared.register(id: id, order: -1) {
                NavigationPlugin.shared
            }
        }
    }
}
