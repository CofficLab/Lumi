import LumiCoreKit
import SwiftUI
import os

/// 编辑器符号面包屑插件
///
/// 作为 Panel Header 提供者，在编辑器面板顶部显示当前光标位置的符号路径。
actor EditorStickySymbolBarPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-sticky-symbol-bar")

    nonisolated static let emoji = "🧩"
    nonisolated static let verbose: Bool = true
    static let id: String = "EditorStickySymbolBar"
    static let displayName: String = String(
        localized: "Editor Sticky Symbol Bar", table: "EditorStickySymbolBar")
    static let description: String = String(
        localized: "Current symbol breadcrumb for the editor panel",
        table: "EditorStickySymbolBar")
    static let iconName = "point.topleft.down.curvedto.point.bottomright.up"
    static var category: PluginCategory { .editor }
    static var order: Int { 89 }
    nonisolated static let policy: PluginPolicy = .disabled

    /// 插件注册策略：开发中，暂不注册

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorStickySymbolBarPlugin()

    @MainActor
    func addPanelHeaderView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorStickySymbolBarHeaderView())
    }
}
