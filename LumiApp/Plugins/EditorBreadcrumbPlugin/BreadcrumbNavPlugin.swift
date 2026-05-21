import Foundation
import SwiftUI
import os

/// 面包屑导航插件：在编辑器面板头部显示当前文件路径的面包屑导航
///
/// 类似 VS Code 的面包屑导航，提供可点击的文件路径段，支持快速导航到同级文件/文件夹。
actor BreadcrumbNavPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.breadcrumb-nav")

    nonisolated static let emoji = "🧭"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "BreadcrumbNav"
    static let displayName: String = String(localized: "Breadcrumb Navigation", table: "BreadcrumbNav")
    static let description: String = String(localized: "File path breadcrumb navigation below editor tabs", table: "BreadcrumbNav")
    static let iconName: String = "point.topleft.down.curvedto.point.bottomright.up"
    static var isConfigurable: Bool { false }
    static var order: Int { 70 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = BreadcrumbNavPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    /// 在编辑器面板头部显示面包屑导航（Tab 栏下方）
    @MainActor
    func addPanelHeaderView(activeIcon: String?) -> AnyView? {
        // 仅在编辑器面板激活时提供
        guard activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(BreadcrumbNavHeaderView())
    }
}
