import LumiCoreKit
import SuperLogKit
import Foundation
import SwiftUI
import TerminalCoreKit
import os

/// 编辑器底部面板 - Terminal 标签页插件
///
/// 向内核全局底部面板注册 Terminal Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
///
/// 注意：此插件使用独立的 TerminalTabsViewModel 实例，
/// 与 TerminalPlugin（侧边栏终端）完全隔离，不共享会话状态。
public actor EditorBottomTerminalPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-terminal")

    public nonisolated static let emoji = "💻"
    public nonisolated static let verbose: Bool = true
    public static let id: String = "EditorBottomTerminal"
    public static let displayName: String = String(
        localized: "Editor Bottom Terminal", table: "EditorBottomTerminal")
    public static let description: String = String(
        localized: "Terminal panel in the editor bottom area", table: "EditorBottomTerminal")
    public static let iconName: String = "terminal"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 100 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorBottomTerminalPlugin()

    // MARK: - Bottom Panel Tabs

    @MainActor public func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] {
        []
    }

    @MainActor public func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? {
        nil
    }
}
