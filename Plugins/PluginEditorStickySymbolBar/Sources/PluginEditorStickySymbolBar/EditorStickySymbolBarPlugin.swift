import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

/// 编辑器符号面包屑插件
///
/// 作为 Panel Header 提供者，在编辑器面板顶部显示当前光标位置的符号路径。
public actor EditorStickySymbolBarPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-sticky-symbol-bar")

    public nonisolated static let emoji = "🧩"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "EditorStickySymbolBar"
    public static let displayName: String = String(
        localized: "Editor Sticky Symbol Bar", table: "EditorStickySymbolBar")
    public static let description: String = String(
        localized: "Current symbol breadcrumb for the editor panel",
        table: "EditorStickySymbolBar")
    public static let iconName = "point.topleft.down.curvedto.point.bottomright.up"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 89 }
    public nonisolated static let policy: PluginPolicy = .disabled

    /// 插件注册策略：开发中，暂不注册

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorStickySymbolBarPlugin()

    @MainActor
    public func addPanelHeaderView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        return AnyView(EditorStickySymbolBarHeaderView())
    }
}
