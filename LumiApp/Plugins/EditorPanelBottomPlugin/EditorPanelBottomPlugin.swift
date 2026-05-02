import Foundation
import MagicKit
import SwiftUI
import os

/// 编辑器底部面板插件
///
/// 作为 Panel Bottom 提供者，当编辑器面板激活时，
/// 在面板内容下方渲染底部面板（Problems、References、Search Results 等）。
actor EditorPanelBottomPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-panel-bottom")

    nonisolated static let emoji = "⬇️"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorPanelBottom"
    static let displayName: String = String(
        localized: "Editor Panel Bottom", table: "EditorPanelBottom")
    static let description: String = String(
        localized: "Bottom panel for the editor (Problems, References, Search Results, etc.)",
        table: "EditorPanelBottom")
    static let iconName: String = "square.split.bottomthird.twofills"
    static var isConfigurable: Bool { false }
    static var order: Int { 79 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorPanelBottomPlugin()

    // MARK: - UI Contributions

    /// 当编辑器面板激活时，提供 Panel Bottom 视图
    @MainActor func addPanelBottomView(activeIcon: String?) -> AnyView? {
        guard activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorBottomPanelContainerView())
    }
}