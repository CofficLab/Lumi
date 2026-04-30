import MagicKit
import SwiftUI
import AppKit
import Combine
import Foundation
import os

/// 菜单栏管理插件：管理菜单栏图标的显示与隐藏
actor MenuBarManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.menubar-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "🧊"

    nonisolated static let enable: Bool = false
    nonisolated static let verbose: Bool = true

    static let id: String = "MenuBarManager"
    static let navigationId: String = "menu_bar_manager"
    static let displayName: String = String(localized: "Menu Bar Manager", table: "MenuBarManager")
    static let description: String = String(localized: "Manage your menu bar items", table: "MenuBarManager")
    static let iconName = "menubar.rectangle"
    static let isConfigurable: Bool = false
    static var order: Int { 20 }

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = MenuBarManagerPlugin()

    // MARK: - UI Contributions

    /// 该面板不需要右侧栏

    @MainActor
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == Self.iconName else { return nil }
        return AnyView(MenuBarSettingsView())
    }

    nonisolated func addPanelIcon() -> String? { Self.iconName }

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
        .inRootView()
        .withDebugBar()
}
