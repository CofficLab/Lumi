import LumiCoreKit
import Foundation
import SwiftUI
import os

/// 编辑器调用层级 Rail 插件：提供 Call Hierarchy 标签页
actor EditorCallHierarchyRailPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-call-hierarchy-rail")

    nonisolated static let emoji = "📞"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true
    static let id: String = "EditorCallHierarchyRail"
    static let displayName: String = String(
        localized: "Editor Call Hierarchy Rail", table: "EditorCallHierarchyRail")
    static let description: String = String(
        localized: "Editor sidebar call hierarchy tab",
        table: "EditorCallHierarchyRail")
    static let iconName: String = "point.3.connected.trianglepath.dotted"
    static var isConfigurable: Bool { false }
    static var category: PluginCategory { .editor }
    static var order: Int { 78 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorCallHierarchyRailPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor func addRailTabs(context: PluginContext) -> [RailTab] {
        guard context.activeIcon == EditorPlugin.iconName else { return [] }
        return [RailTab(id: "callHierarchy", title: String(localized: "Calls", table: "EditorCallHierarchyRail"), systemImage: "point.3.connected.trianglepath.dotted", priority: 14)]
    }

    @MainActor func addRailContentView(tabId: String, context: PluginContext) -> AnyView? {
        guard tabId == "callHierarchy", context.activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorCallHierarchyRailContentView())
    }
}

/// Call Hierarchy 标签页内容视图
struct EditorCallHierarchyRailContentView: View {
    @EnvironmentObject private var editorVM: WindowEditorVM

    private var service: EditorService { editorVM.service }

    var body: some View {
        EditorCallHierarchyPanelView(service: service, showsHeader: false)
    }
}
