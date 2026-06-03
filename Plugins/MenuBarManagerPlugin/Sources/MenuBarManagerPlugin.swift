import SwiftUI
import LumiUI
import SuperLogKit
import AppKit
import Combine
import Foundation
import os
import LumiCoreKit

/// 菜单栏管理插件：管理菜单栏图标的显示与隐藏
public actor MenuBarManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.menubar-manager")

    // MARK: - Plugin Properties

    public nonisolated static let emoji = "🧊"

    public static var category: PluginCategory { .general }
    public nonisolated static let verbose: Bool = true

    public static let id: String = "MenuBarManager"
    public static let navigationId: String = "menu_bar_manager"
    public static let displayName: String = String(localized: "Menu Bar Manager", bundle: .module)
    public static let description: String = String(localized: "Manage your menu bar items", bundle: .module)
    public static let iconName = "menubar.rectangle"
    public static var order: Int { 20 }

    public nonisolated static let policy: PluginPolicy = .disabled
    
    /// 插件注册策略：可配置，默认不启用（可选功能）

    // MARK: - Instance

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = MenuBarManagerPlugin()

    public nonisolated func onEnable() {
        Task { @MainActor in
            MenuBarManagerService.shared.startMonitoring()
        }
    }

    public nonisolated func onDisable() {
        Task { @MainActor in
            MenuBarManagerService.shared.stopMonitoring()
        }
    }

    // MARK: - UI Contributions

    

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(MenuBarSettingsView())
        }
    }

    /// 添加菜单栏弹窗视图
    /// 我们可以在这里放一个开关，或者一个"Thaw"按钮来显示隐藏的项目
    @MainActor public func addMenuBarPopupView() -> AnyView? {
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
