import Foundation
import SwiftUI
import os
import MagicKit

/// 编辑器调用层级 Rail 插件：提供 Call Hierarchy 标签页
actor EditorCallHierarchyRailPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-call-hierarchy-rail")

    nonisolated static let emoji = "📞"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorCallHierarchyRail"
    static let displayName: String = String(
        localized: "Editor Call Hierarchy Rail", table: "EditorCallHierarchyRail")
    static let description: String = String(
        localized: "Editor sidebar call hierarchy tab",
        table: "EditorCallHierarchyRail")
    static let iconName: String = "point.3.connected.trianglepath.dotted"
    static var isConfigurable: Bool { false }
    static var order: Int { 78 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorCallHierarchyRailPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor func addRailTabs(activeIcon: String?) -> [RailTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [RailTab(id: "callHierarchy", title: String(localized: "Calls", table: "EditorCallHierarchyRail"), systemImage: "point.3.connected.trianglepath.dotted", priority: 14)]
    }

    @MainActor func addRailContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "callHierarchy", activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorCallHierarchyRailContentView())
    }
}

/// Call Hierarchy 标签页内容视图
struct EditorCallHierarchyRailContentView: View {
    @EnvironmentObject private var editorVM: EditorVM

    private var state: EditorState { editorVM.service.state }

    var body: some View {
        EditorCallHierarchyPanelView(state: state, showsHeader: false)
    }
}
