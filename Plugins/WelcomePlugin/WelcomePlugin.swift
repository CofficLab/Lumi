import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 欢迎插件：提供欢迎界面作为详情视图
actor WelcomePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "⭐️"

    /// 是否启用该插件
    static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    static var id: String = "WelcomePlugin"

    /// 插件显示名称
    static var displayName: String = "欢迎页面"

    /// 插件功能描述
    static var description: String = "显示应用欢迎界面和使用指南"

    /// 插件图标名称
    static var iconName: String = "star.circle.fill"

    /// 是否可配置
    static var isConfigurable: Bool = true
    
    /// 注册顺序
    static var order: Int { 0 }

    // MARK: - Instance

    /// 插件单例实例
    static let shared = WelcomePlugin()

    // MARK: - UI Contributions

    /// 提供导航入口
    /// - Returns: 导航入口数组
    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: "\(Self.id).welcome",
                title: "欢迎",
                icon: "star.circle.fill",
                pluginId: Self.id,
                isDefault: true
            ) {
                WelcomeView()
            }
        ]
    }

    /// 添加详情视图
    /// - Returns: 详情视图
    @MainActor func addDetailView() -> AnyView? {
        return AnyView(WelcomeView())
    }
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800)
        .frame(height: 600)
}
