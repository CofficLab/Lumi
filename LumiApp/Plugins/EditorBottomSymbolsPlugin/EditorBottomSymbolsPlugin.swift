import Foundation
import MagicKit
import SwiftUI
import os

/// 编辑器底部面板 - Workspace Symbols 标签页插件
///
/// 向内核全局底部面板注册 Workspace Symbols Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
actor EditorBottomSymbolsPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-symbols")

    nonisolated static let emoji = "🔣"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorBottomSymbols"
    static let displayName: String = String(
        localized: "Editor Bottom Symbols", table: "EditorBottomSymbols")
    static let description: String = String(
        localized: "Workspace Symbols panel in the editor bottom area",
        table: "EditorBottomSymbols")
    static let iconName: String = "text.magnifyingglass"
    static var isConfigurable: Bool { false }
    static var order: Int { 79 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorBottomSymbolsPlugin()

    // MARK: - Bottom Panel Tabs

    @MainActor func addBottomPanelTabs(activeIcon: String?) -> [BottomPanelTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [BottomPanelTab(
            id: "editor-bottom-symbols",
            title: "Workspace Symbols",
            systemImage: "text.magnifyingglass",
            priority: 3
        )]
    }

    @MainActor func addBottomPanelContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "editor-bottom-symbols", activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorBottomSymbolsContentView())
    }
}

/// Workspace Symbols 底部面板内容视图
struct EditorBottomSymbolsContentView: View {
    @EnvironmentObject private var editorVM: EditorVM

    private var service: EditorService { editorVM.service }

    var body: some View {
        BottomEditorWorkspaceSymbolsPanelView(service: service, showsHeader: false)
    }
}
