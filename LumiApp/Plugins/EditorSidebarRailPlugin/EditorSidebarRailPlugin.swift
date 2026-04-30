import Foundation
import SwiftUI
import os
import MagicKit

/// 编辑器侧边栏 Rail 插件：提供编辑器的文件浏览、大纲、问题面板等侧边栏视图
///
/// 通过 Rail 视图机制，在活动栏与面板内容区之间显示侧边栏 workspace。
/// 包含 Explorer、Open Editors、Outline、Problems、Search、References、
/// Workspace Symbols、Call Hierarchy 等标签页。
actor EditorSidebarRailPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-sidebar-rail")

    nonisolated static let emoji = "🗂️"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorSidebarRail"
    static let displayName: String = String(
        localized: "Editor Sidebar Rail", table: "EditorSidebarRail")
    static let description: String = String(
        localized: "Editor sidebar workspace with explorer, outline, problems and more",
        table: "EditorSidebarRail")
    static let iconName: String = "sidebar.left"
    static var isConfigurable: Bool { false }
    static var order: Int { 78 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorSidebarRailPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    /// 提供 Rail 视图：编辑器侧边栏 workspace
    ///
    /// 仅在 EditorPlugin（icon: `chevron.left.forwardslash.chevron.right`）被激活时提供。
    @MainActor func addRailView(activeIcon: String?) -> AnyView? {
        guard activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        return AnyView(EditorSidebarRailView())
    }
}

// MARK: - 预览

#Preview("Editor Sidebar Rail") {
    ContentLayout()
        .inRootView()
        .frame(width: 320, height: 600)
}
