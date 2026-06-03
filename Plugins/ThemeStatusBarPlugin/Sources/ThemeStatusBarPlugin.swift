import Foundation
import SuperLogKit
import os
import LumiCoreKit

/// 主题状态栏插件
///
/// 负责主题的持久化（保存/恢复）以及在状态栏展示主题切换入口。
/// 通过 `addRootView` 注入 `ThemePersistenceAnchor`，利用环境中的 `AppThemeVM`：
/// - **恢复**：视图 onAppear 时读取本地存储并调用 `selectTheme()` 恢复上次选择。
/// - **保存**：监听 `AppThemeVM.currentThemeId` 变化，自动写入本地存储。
public actor ThemeStatusBarPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-theme-status")
    public nonisolated static let emoji = "🎨"
    public nonisolated static let verbose: Bool = true

    public static let id: String = "EditorThemeStatusBar"
    public static let displayName: String = "Editor Theme Status"
    public static let description: String = "Persist and switch editor theme in the status bar"
    public static let iconName: String = "paintbrush"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 76 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = ThemeStatusBarPlugin()
    public nonisolated func onRegister() {}

}
