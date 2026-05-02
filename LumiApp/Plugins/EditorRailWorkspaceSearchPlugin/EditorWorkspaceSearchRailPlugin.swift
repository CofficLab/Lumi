import Foundation
import SwiftUI
import os
import MagicKit

/// 编辑器工作区搜索 Rail 插件：提供 Search 标签页
actor EditorWorkspaceSearchRailPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-workspace-search-rail")

    nonisolated static let emoji = "🔍"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorWorkspaceSearchRail"
    static let displayName: String = String(
        localized: "Editor Workspace Search Rail", table: "EditorWorkspaceSearchRail")
    static let description: String = String(
        localized: "Editor sidebar search tab",
        table: "EditorWorkspaceSearchRail")
    static let iconName: String = "magnifyingglass"
    static var isConfigurable: Bool { false }
    static var order: Int { 78 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorWorkspaceSearchRailPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor func addRailTabs(activeIcon: String?) -> [RailTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [RailTab(id: "searchResults", title: "Search", systemImage: "magnifyingglass", priority: 11)]
    }

    @MainActor func addRailContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "searchResults", activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorWorkspaceSearchRailContentView())
    }
}

/// Search 标签页内容视图
struct EditorWorkspaceSearchRailContentView: View {
    @EnvironmentObject private var editorVM: EditorVM

    private var state: EditorState { editorVM.service.state }

    var body: some View {
        EditorWorkspaceSearchPanelView(state: state, showsToolbar: true)
    }
}
