import Foundation
import SwiftUI
import os
import MagicKit

/// 编辑器工作区符号 Rail 插件：提供 Symbols 标签页
actor EditorRailWorkspaceSymbolsPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-rail-workspace-symbols")

    nonisolated static let emoji = "🔣"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorRailWorkspaceSymbols"
    static let displayName: String = String(
        localized: "Editor Rail Workspace Symbols", table: "EditorRailWorkspaceSymbols")
    static let description: String = String(
        localized: "Editor sidebar workspace symbols tab",
        table: "EditorRailWorkspaceSymbols")
    static let iconName: String = "text.magnifyingglass"
    static var isConfigurable: Bool { false }
    static var order: Int { 78 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorRailWorkspaceSymbolsPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor func addRailTabs(activeIcon: String?) -> [RailTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [RailTab(id: "workspaceSymbols", title: "Symbols", systemImage: "text.magnifyingglass", priority: 13)]
    }

    @MainActor func addRailContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "workspaceSymbols", activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorWorkspaceSymbolsRailContentView())
    }
}

/// Symbols 标签页内容视图
struct EditorWorkspaceSymbolsRailContentView: View {
    @EnvironmentObject private var editorVM: EditorVM

    private var state: EditorState { editorVM.service.state }

    var body: some View {
        EditorWorkspaceSymbolsPanelView(state: state, showsHeader: false)
    }
}