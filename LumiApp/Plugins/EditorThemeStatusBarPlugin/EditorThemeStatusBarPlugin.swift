import MagicKit
import SwiftUI
import Foundation
import os

/// 编辑器主题状态栏插件：
/// 将编辑器主题切换入口独立为 Lumi 顶层插件，避免耦合在 AgentEditorPlugin 内。
actor EditorThemeStatusBarPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-theme-status")
    nonisolated static let emoji = "🎨"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "EditorThemeStatusBar"
    static let displayName: String = "Editor Theme Status"
    static let description: String = "Display and switch editor theme in the status bar"
    static let iconName: String = "paintbrush"
    static let isConfigurable: Bool = false
    static var order: Int { 76 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorThemeStatusBarPlugin()

    @MainActor
    func addStatusBarTrailingView() -> AnyView? {
        AnyView(EditorThemeStatusBarView())
    }
}
