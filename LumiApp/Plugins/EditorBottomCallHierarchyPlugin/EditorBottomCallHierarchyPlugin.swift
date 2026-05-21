import Foundation
import SwiftUI
import os

/// 编辑器底部面板 - Call Hierarchy 标签页插件
///
/// 向内核全局底部面板注册 Call Hierarchy Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
actor EditorBottomCallHierarchyPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-call-hierarchy")

    nonisolated static let emoji = "📞"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorBottomCallHierarchy"
    static let displayName: String = String(
        localized: "Editor Bottom Call Hierarchy", table: "EditorBottomCallHierarchy")
    static let description: String = String(
        localized: "Call Hierarchy panel in the editor bottom area",
        table: "EditorBottomCallHierarchy")
    static let iconName: String = "point.3.connected.trianglepath.dotted"
    static var isConfigurable: Bool { false }
    static var order: Int { 79 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorBottomCallHierarchyPlugin()

    // MARK: - Bottom Panel Tabs

    @MainActor func addBottomPanelTabs(activeIcon: String?) -> [BottomPanelTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [BottomPanelTab(
            id: "editor-bottom-call-hierarchy",
            title: String(localized: "Call Hierarchy", table: "EditorBottomCallHierarchy"),
            systemImage: "point.3.connected.trianglepath.dotted",
            priority: 4
        )]
    }

    @MainActor func addBottomPanelContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "editor-bottom-call-hierarchy", activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorBottomCallHierarchyContentView())
    }
}

/// Call Hierarchy 底部面板内容视图
struct EditorBottomCallHierarchyContentView: View {
    @EnvironmentObject private var editorVM: WindowEditorVM

    private var service: EditorService { editorVM.service }

    var body: some View {
        BottomEditorCallHierarchyPanelView(service: service, showsHeader: false)
    }
}
