import Foundation
import SwiftUI
import os
import MagicKit

/// 编辑器引用 Rail 插件：提供 References 标签页
actor EditorRailReferencesPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-rail-references")

    nonisolated static let emoji = "🔗"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorRailReferences"
    static let displayName: String = String(
        localized: "Editor Rail References", table: "EditorRailReferences")
    static let description: String = String(
        localized: "Editor sidebar references tab",
        table: "EditorRailReferences")
    static let iconName: String = "arrow.triangle.branch"
    static var isConfigurable: Bool { false }
    static var order: Int { 78 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorRailReferencesPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor func addRailTabs(activeIcon: String?) -> [RailTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [RailTab(id: "references", title: "References", systemImage: "arrow.triangle.branch", priority: 12)]
    }

    @MainActor func addRailContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "references", activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorReferencesRailContentView())
    }
}

/// References 标签页内容视图
struct EditorReferencesRailContentView: View {
    @EnvironmentObject private var editorVM: EditorVM

    private var state: EditorState { editorVM.service.state }

    var body: some View {
        EditorReferencesWorkspacePanelView(state: state, showsHeader: false)
    }
}