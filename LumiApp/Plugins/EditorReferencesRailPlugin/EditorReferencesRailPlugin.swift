import Foundation
import SwiftUI
import os
import MagicKit

/// 编辑器引用 Rail 插件：提供 References 标签页
actor EditorReferencesRailPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-references-rail")

    nonisolated static let emoji = "🔗"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorReferencesRail"
    static let displayName: String = String(
        localized: "Editor References Rail", table: "EditorReferencesRail")
    static let description: String = String(
        localized: "Editor sidebar references tab",
        table: "EditorReferencesRail")
    static let iconName: String = "arrow.triangle.branch"
    static var isConfigurable: Bool { false }
    static var order: Int { 78 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorReferencesRailPlugin()

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
