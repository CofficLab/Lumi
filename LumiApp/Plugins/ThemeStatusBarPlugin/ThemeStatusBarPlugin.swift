import MagicKit
import SwiftUI
import Foundation
import os

/// 主题状态栏插件
///
/// 负责主题的持久化（保存/恢复）以及在状态栏展示主题切换入口。
/// 通过 `addRootView` 注入 `ThemePersistenceAnchor`，利用环境中的 `ThemeVM`：
/// - **恢复**：视图 onAppear 时读取本地存储并调用 `selectTheme()` 恢复上次选择。
/// - **保存**：监听 `ThemeVM.currentThemeId` 变化，自动写入本地存储。
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

    nonisolated func onRegister() {}

    // MARK: - Root View（主题持久化锚点）

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ThemePersistenceAnchor(content: content()))
    }

    // MARK: - Status Bar

    @MainActor
    func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        AnyView(ThemeStatusBarView())
    }
}

// MARK: - Theme Persistence Anchor

/// 主题持久化锚点视图
///
/// 作为 `addRootView` 注入的全局透明视图，承担两个职责：
/// 1. **恢复**：首次出现时从本地存储读取已保存的主题 ID，调用 `ThemeVM.selectTheme()` 恢复。
/// 2. **保存**：监听 `ThemeVM.currentThemeId` 变化，自动持久化到本地存储。
///
/// 此视图不渲染任何可见内容，仅作为生命周期锚点。
private struct ThemePersistenceAnchor<Content: View>: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @EnvironmentObject private var editorVM: EditorVM
    let content: Content

    /// 标记是否已完成首次恢复，避免恢复触发 didSet 又写回存储
    @State private var hasRestored = false

    var body: some View {
        content
            .onAppear {
                restoreSavedTheme()
                // 主动将 ThemeVM 当前主题同步到 EditorState。
                // ThemeVM.init() 在 EditorState 之前创建，其发送的 .lumiThemeDidChange
                // 通知在 EditorState 注册监听之前就已经发出，导致 EditorState 错过了初始通知。
                // 此处由插件（外层）主动向 EditorState（内层）推送，而非 EditorState 反向读取 ThemeVM。
                let editorThemeId = themeVM.activeEditorThemeId
                ThemeStatusBarPlugin.logger.info("\(ThemeStatusBarPlugin.t)onAppear: 同步初始编辑器主题 → \(editorThemeId, privacy: .public)")
                editorVM.syncInitialEditorTheme(editorThemeId)
            }
            .onChange(of: themeVM.currentThemeId) { oldValue, newValue in
                guard hasRestored else { return }
                guard oldValue != newValue else { return }
                ThemeStatusBarPlugin.logger.info("\(ThemeStatusBarPlugin.t)主题变更: \(oldValue, privacy: .public) → \(newValue, privacy: .public)")
                ThemeStatusBarPluginLocalStore.shared.saveSelectedThemeID(newValue)
            }
    }

    /// 从本地存储恢复上次保存的主题
    private func restoreSavedTheme() {
        guard !hasRestored else { return }
        hasRestored = true

        guard let savedId = ThemeStatusBarPluginLocalStore.shared.loadSelectedThemeID() else {
            ThemeStatusBarPlugin.logger.info("\(ThemeStatusBarPlugin.t)无已保存主题，使用默认主题")
            return
        }
        ThemeStatusBarPlugin.logger.info("\(ThemeStatusBarPlugin.t)恢复已保存主题: \(savedId, privacy: .public)")
        themeVM.selectTheme(savedId)
    }
}
