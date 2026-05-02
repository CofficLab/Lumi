import SwiftUI
import MagicKit
import os

/// 编辑器 Tab 栏插件
///
/// 作为 Panel Header 提供者，当编辑器面板激活时，
/// 在面板内容上方渲染 Tab 栏和 breadcrumb。
actor EditorTabStripPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-tab-strip")

    nonisolated static let emoji = "📑"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "EditorTabStrip"
    static let displayName: String = String(localized: "Editor Tab Strip", table: "EditorTabStrip")
    static let description: String = String(
        localized: "Tab bar and breadcrumb for the editor panel", table: "EditorTabStrip")
    static let iconName = "rectangle.topthird.inset.filled"
    static var isConfigurable: Bool { false }
    static var order: Int { 76 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorTabStripPlugin()

    // MARK: - UI Contributions

    /// 当编辑器面板激活时，提供 Panel Header 视图
    @MainActor
    func addPanelHeaderView(activeIcon: String?) -> AnyView? {
        // 仅在编辑器面板激活时提供 header
        guard activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        return AnyView(EditorTabHeaderView())
    }
}
