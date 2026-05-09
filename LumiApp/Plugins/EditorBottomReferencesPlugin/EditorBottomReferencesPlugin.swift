import Foundation
import MagicKit
import SwiftUI
import os

/// 编辑器底部面板 - References 标签页插件
///
/// 向内核全局底部面板注册 References Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
actor EditorBottomReferencesPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-references")

    nonisolated static let emoji = "🔗"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorBottomReferences"
    static let displayName: String = String(
        localized: "Editor Bottom References", table: "EditorBottomReferences")
    static let description: String = String(
        localized: "References panel in the editor bottom area",
        table: "EditorBottomReferences")
    static let iconName: String = "arrow.triangle.branch"
    static var isConfigurable: Bool { false }
    static var order: Int { 79 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorBottomReferencesPlugin()

    // MARK: - Bottom Panel Tabs

    @MainActor func addBottomPanelTabs(activeIcon: String?) -> [BottomPanelTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [BottomPanelTab(
            id: "editor-bottom-references",
            title: "References",
            systemImage: "arrow.triangle.branch",
            priority: 1
        )]
    }

    @MainActor func addBottomPanelContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "editor-bottom-references", activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorBottomReferencesContentView())
    }
}

/// References 底部面板内容视图
struct EditorBottomReferencesContentView: View {
    @EnvironmentObject private var editorVM: EditorVM

    private var service: EditorService { editorVM.service }

    var body: some View {
        BottomEditorReferencesWorkspacePanelView(service: service, showsHeader: false)
    }
}
