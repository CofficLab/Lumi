import AppKit
import Combine
import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 菜单栏管理插件：管理菜单栏图标的显示与隐藏
actor MenuBarManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "🧊"

    /// 是否启用该插件
    nonisolated static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    nonisolated(unsafe) static var id: String = "MenuBarManagerPlugin"

    static let navigationId = "\(id).settings"

    /// 插件显示名称
    nonisolated(unsafe) static var displayName: String = "Menu Bar Manager"

    /// 插件功能描述
    nonisolated(unsafe) static var description: String = "Manage your menu bar items"

    /// 插件图标名称
    nonisolated(unsafe) static var iconName: String = "menubar.rectangle"

    /// 是否可配置
    nonisolated(unsafe) static var isConfigurable: Bool = true

    /// 注册顺序
    nonisolated(unsafe) static var order: Int { 20 }

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    nonisolated var instanceLabel: String {
        Self.id
    }

    static let shared = MenuBarManagerPlugin()

    // MARK: - UI Contributions

    /// 提供导航入口（用于侧边栏导航）
    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        [
            NavigationEntry(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id,
                contentProvider: { AnyView(MenuBarSettingsView()) }
            ),
        ]
    }

    /// 添加状态栏弹窗视图
    /// 我们可以在这里放一个开关，或者一个"Thaw"按钮来显示隐藏的项目
    @MainActor func addStatusBarPopupView() -> AnyView? {
        // 暂时不添加专门的弹窗，主要通过设置页面管理
        nil
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(MenuBarManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
