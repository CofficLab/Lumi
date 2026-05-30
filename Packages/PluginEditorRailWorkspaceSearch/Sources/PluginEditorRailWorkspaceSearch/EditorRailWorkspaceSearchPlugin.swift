import LumiCoreKit
import SuperLogKit
import Foundation
import SwiftUI
import os

/// 编辑器工作区搜索 Rail 插件：提供 Search 标签页
public actor EditorRailWorkspaceSearchPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-rail-workspace-search")

    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "EditorRailWorkspaceSearch"
    public static let displayName: String = String(
        localized: "Editor Rail Workspace Search", table: "EditorRailWorkspaceSearch")
    public static let description: String = String(
        localized: "Editor sidebar search tab",
        table: "EditorRailWorkspaceSearch")
    public static let iconName: String = "magnifyingglass"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 78 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorRailWorkspaceSearchPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor public func addRailTabs(context: PluginContext) -> [RailTab] {
        []
    }

    @MainActor public func addRailContentView(tabId: String, context: PluginContext) -> AnyView? {
        nil
    }
}
