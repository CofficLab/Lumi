import Foundation
import MagicKit
import SwiftUI
import os

/// 编辑器底部面板 - Search 标签页插件
///
/// 向内核全局底部面板注册 Search Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
actor EditorBottomSearchPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-search")

    nonisolated static let emoji = "🔍"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorBottomSearch"
    static let displayName: String = String(
        localized: "Editor Bottom Search", table: "EditorBottomSearch")
    static let description: String = String(
        localized: "Search panel in the editor bottom area",
        table: "EditorBottomSearch")
    static let iconName: String = "magnifyingglass"
    static var isConfigurable: Bool { false }
    static var order: Int { 79 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorBottomSearchPlugin()

    // MARK: - Bottom Panel Tabs

    @MainActor func addBottomPanelTabs(activeIcon: String?) -> [BottomPanelTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [BottomPanelTab(
            id: "editor-bottom-search",
            title: "Search",
            systemImage: "magnifyingglass",
            priority: 2
        )]
    }

    @MainActor func addBottomPanelContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "editor-bottom-search", activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorBottomSearchContentView())
    }
}

/// Search 底部面板内容视图
struct EditorBottomSearchContentView: View {
    @EnvironmentObject private var editorVM: EditorVM

    private var service: EditorService { editorVM.service }

    var body: some View {
        BottomEditorWorkspaceSearchPanelView(service: service, showsToolbar: true)
    }
}
