import Foundation
import LumiCoreKit
import LumiUI
import SuperLogKit
import os
import SwiftUI

/// 主题状态栏插件
///
/// 负责主题的持久化（保存/恢复）以及在状态栏展示主题切换入口。
/// 通过 `addRootView` 注入 `ThemePersistenceAnchor`，利用 `LumiUIThemeRegistry`：
/// - **恢复**：视图 onAppear 时读取本地存储并调用 `LumiUIThemeRegistry.select(themeId:)` 恢复。
/// - **保存**：监听 `LumiUIThemeRegistry.selectedThemeId` 变化，自动写入本地存储。
public actor ThemeStatusBarPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-theme-status")
    public nonisolated static let emoji = "🎨"
    public nonisolated static let verbose: Bool = false

    public static let id: String = "EditorThemeStatusBar"
    public static let displayName: String = String(localized: "Editor Theme Status", bundle: .module)
    public static let description: String = String(localized: "Persist and switch editor theme in the status bar", bundle: .module)
    public static let iconName: String = "paintbrush"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 76 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = ThemeStatusBarPlugin()
    public nonisolated func onRegister() {}

    // MARK: - Root View（主题持久化锚点）

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ThemePersistenceAnchor(content: content()))
    }

    // MARK: - Status Bar

    @MainActor
    public func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        AnyView(ThemeStatusBarView())
    }
}

// MARK: - Theme Persistence Anchor

/// 主题持久化锚点视图
///
/// 作为 `addRootView` 注入的全局透明视图，承担两个职责：
/// 1. **恢复**：首次出现时从本地存储读取已保存的主题 ID，调用 `LumiUIThemeRegistry.select(themeId:)` 恢复。
/// 2. **保存**：监听 `LumiUIThemeRegistry.selectedThemeId` 变化，自动持久化到本地存储。
///
/// 此视图不渲染任何可见内容，仅作为生命周期锚点。
private struct ThemePersistenceAnchor<Content: View>: View {
    @ObservedObject private var registry = LumiUIThemeRegistry.shared
    let content: Content

    /// 标记是否已完成首次恢复，避免恢复触发 didSet 又写回存储
    @State private var hasRestored = false

    var body: some View {
        content
            .onAppear {
                restoreSavedTheme()
            }
            .onChange(of: registry.selectedThemeId) { oldValue, newValue in
                guard hasRestored else { return }
                guard let newValue else { return }
                guard oldValue != newValue else { return }
                if ThemeStatusBarPlugin.verbose {
                    ThemeStatusBarPlugin.logger.info("主题变更: \(oldValue ?? "nil", privacy: .public) → \(newValue, privacy: .public)")
                }
                ThemeStatusBarPluginLocalStore.shared.saveSelectedThemeID(newValue)
            }
    }

    /// 从本地存储恢复上次保存的主题
    private func restoreSavedTheme() {
        guard !hasRestored else { return }
        hasRestored = true

        guard let savedId = ThemeStatusBarPluginLocalStore.shared.loadSelectedThemeID() else {
            if ThemeStatusBarPlugin.verbose {
                ThemeStatusBarPlugin.logger.info("无已保存主题，使用默认主题")
            }
            return
        }
        if ThemeStatusBarPlugin.verbose {
            ThemeStatusBarPlugin.logger.info("恢复已保存主题: \(savedId, privacy: .public)")
        }
        try? registry.select(themeId: savedId)
    }
}
