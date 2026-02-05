import Foundation
import MagicKit
import SwiftUI
import OSLog

/// 导航插件：在侧边栏提供导航按钮
actor NavigationPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "🧭"

    /// 是否启用该插件
    static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    static let id: String = "NavigationPlugin"

    /// 插件显示名称
    static let displayName: String = "导航"

    /// 插件功能描述
    static let description: String = "在侧边栏提供主导航按钮"

    /// 插件图标名称
    static let iconName: String = "sidebar.left"

    /// 是否可配置
    static let isConfigurable: Bool = false
    
    /// 注册顺序
    static var order: Int { -1 }

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// 插件单例实例
    static let shared = NavigationPlugin()

    /// 初始化方法
    init() {}

    // MARK: - UI Contributions

    /// 添加侧边栏视图
    /// - Returns: 要添加到侧边栏的视图
    @MainActor func addSidebarView() -> AnyView? {
        return AnyView(NavigationSidebarView())
    }
}


