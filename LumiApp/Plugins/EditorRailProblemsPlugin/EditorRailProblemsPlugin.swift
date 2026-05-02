import Foundation
import SwiftUI
import os
import MagicKit

/// 编辑器问题面板 Rail 插件：提供 Problems 标签页
actor EditorRailProblemsPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-rail-problems")

    nonisolated static let emoji = "⚠️"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorRailProblems"
    static let displayName: String = String(
        localized: "Editor Rail Problems", table: "EditorRailProblems")
    static let description: String = String(
        localized: "Editor sidebar problems tab",
        table: "EditorRailProblems")
    static let iconName: String = "exclamationmark.bubble"
    static var isConfigurable: Bool { false }
    static var order: Int { 78 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorRailProblemsPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor func addRailTabs(activeIcon: String?) -> [RailTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [RailTab(id: "problems", title: "Problems", systemImage: "exclamationmark.bubble", priority: 10)]
    }

    @MainActor func addRailContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "problems", activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorProblemsRailContentView())
    }
}

/// Problems 标签页内容视图
struct EditorProblemsRailContentView: View {
    @EnvironmentObject private var editorVM: EditorVM

    private var state: EditorState { editorVM.service.state }

    var body: some View {
        EditorProblemsPanelView(state: state, showsHeader: false)
    }
}