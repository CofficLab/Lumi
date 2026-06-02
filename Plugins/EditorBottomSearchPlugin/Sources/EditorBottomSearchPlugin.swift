import LumiCoreKit
import SuperLogKit
import Foundation
import SwiftUI
import os

/// 编辑器底部面板 - Search 标签页插件
///
/// 向内核全局底部面板注册 Search Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
public actor EditorBottomSearchPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-search")

    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "EditorBottomSearch"
    public static let displayName: String = String(
        localized: "Editor Bottom Search", table: "EditorBottomSearch")
    public static let description: String = String(
        localized: "Search panel in the editor bottom area",
        table: "EditorBottomSearch")
    public static let iconName: String = "magnifyingglass"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 79 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorBottomSearchPlugin()

    // MARK: - Bottom Panel Tabs

    @MainActor public func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] {
        []
    }

    @MainActor public func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? {
        nil
    }
}
