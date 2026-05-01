import MagicKit
import SwiftUI
import Foundation
import os

/// 主题状态栏插件
actor ThemeStatusBarPlugin: SuperPlugin, SuperLog {
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
    static let shared = ThemeStatusBarPlugin()

    @MainActor
    func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        AnyView(ThemeStatusBarView())
    }
}
