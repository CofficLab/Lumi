import Foundation
import SwiftUI
import os
import MagicKit

/// 编辑器大纲 Rail 插件：提供 Outline 标签页
actor EditorOutlineRailPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-outline-rail")

    nonisolated static let emoji = "📋"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorOutlineRail"
    static let displayName: String = String(
        localized: "Editor Outline Rail", table: "EditorOutlineRail")
    static let description: String = String(
        localized: "Editor sidebar outline tab",
        table: "EditorOutlineRail")
    static let iconName: String = "list.bullet.indent"
    static var isConfigurable: Bool { false }
    static var order: Int { 78 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorOutlineRailPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor func addRailTabs(activeIcon: String?) -> [RailTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [RailTab(id: "outline", title: String(localized: "Outline", table: "EditorOutlineRail"), systemImage: "list.bullet.indent", priority: 1)]
    }

    @MainActor func addRailContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "outline", activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorOutlineRailContentView())
    }
}

/// Outline 标签页内容视图
struct EditorOutlineRailContentView: View {
    @EnvironmentObject private var editorVM: EditorVM

    private var state: EditorState { editorVM.service.state }

    var body: some View {
        if let provider = state.documentSymbolProvider as? DocumentSymbolProvider {
            EditorOutlinePanelView(
                state: state,
                provider: provider,
                showsHeader: false,
                showsResizeHandle: false
            )
        } else {
            Text(String(localized: "Outline not available", table: "EditorOutlineRail"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
