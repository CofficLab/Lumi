import Foundation
import SwiftUI
import os
import MagicKit

/// 编辑器文件树 Rail 插件：提供 Explorer 标签页
actor EditorRailFileTreePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-rail-file-tree")

    nonisolated static let emoji = "📁"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorRailFileTree"
    static let displayName: String = String(
        localized: "Editor Rail File Tree", table: "EditorRailFileTree")
    static let description: String = String(
        localized: "Editor sidebar explorer tab",
        table: "EditorRailFileTree")
    static let iconName: String = "folder"
    static var isConfigurable: Bool { false }
    static var order: Int { 78 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorRailFileTreePlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor func addRailTabs(activeIcon: String?) -> [RailTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [RailTab(id: "explorer", title: String(localized: "Explorer", table: "EditorRailFileTree"), systemImage: "folder", priority: 0)]
    }

    @MainActor func addRailContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "explorer", activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorFileTreeView())
    }
}