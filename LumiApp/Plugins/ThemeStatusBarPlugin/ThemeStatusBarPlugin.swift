import MagicKit
import SwiftUI
import Foundation
import os

/// 主题状态栏插件
///
/// 负责主题的持久化（保存/恢复）以及在状态栏展示主题切换入口。
/// 监听 `.lumiThemeDidChange` 通知，在用户切换主题时自动保存到本地存储。
actor ThemeStatusBarPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-theme-status")
    nonisolated static let emoji = "🎨"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "EditorThemeStatusBar"
    static let displayName: String = "Editor Theme Status"
    static let description: String = "Persist and switch editor theme in the status bar"
    static let iconName: String = "paintbrush"
    static let isConfigurable: Bool = false
    static var order: Int { 76 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ThemeStatusBarPlugin()

    nonisolated func onRegister() {
        // 监听主题切换通知，自动持久化用户选择
        NotificationCenter.default.addObserver(
            forName: .lumiThemeDidChange,
            object: nil,
            queue: .main
        ) { notification in
            guard let themeId = notification.userInfo?["themeId"] as? String else { return }
            ThemeStatusBarPluginLocalStore.shared.saveSelectedThemeID(themeId)
        }
    }

    @MainActor
    func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        AnyView(ThemeStatusBarView())
    }
}
