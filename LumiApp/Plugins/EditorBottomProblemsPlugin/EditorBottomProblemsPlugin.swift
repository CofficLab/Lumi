import Foundation
import MagicKit
import SwiftUI
import os

/// 编辑器底部面板 - Problems 标签页插件
///
/// 向内核全局底部面板注册 Problems Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
actor EditorBottomProblemsPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-problems")

    nonisolated static let emoji = "⚠️"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorBottomProblems"
    static let displayName: String = String(
        localized: "Editor Bottom Problems", table: "EditorBottomProblems")
    static let description: String = String(
        localized: "Problems panel in the editor bottom area",
        table: "EditorBottomProblems")
    static let iconName: String = "exclamationmark.bubble"
    static var isConfigurable: Bool { false }
    static var order: Int { 79 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorBottomProblemsPlugin()

    // MARK: - Bottom Panel Tabs

    @MainActor func addBottomPanelTabs(activeIcon: String?) -> [BottomPanelTab] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [BottomPanelTab(
            id: "editor-bottom-problems",
            title: String(localized: "Problems", table: "EditorBottomProblems"),
            systemImage: "exclamationmark.bubble",
            priority: 0
        )]
    }

    @MainActor func addBottomPanelContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "editor-bottom-problems", activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorBottomProblemsContentView())
    }
}

/// Problems 底部面板内容视图
struct EditorBottomProblemsContentView: View {
    @EnvironmentObject private var editorVM: AppEditorVM

    private var service: EditorService { editorVM.service }

    var body: some View {
        BottomEditorProblemsPanelView(service: service, showsHeader: false)
    }
}
