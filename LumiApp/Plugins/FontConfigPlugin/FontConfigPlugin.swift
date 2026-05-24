import SwiftUI

/// 字体配置插件：在状态栏提供编辑器字体快速切换入口
actor FontConfigPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🔤"
    static var category: PluginCategory { .theme }
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id: String = "FontConfig"
    static let displayName: String = String(
        localized: "Font Config", table: "FontConfig")
    static let description: String = String(
        localized: "Quick font switching in status bar", table: "FontConfig")
    static let iconName: String = "textformat"
    static var isConfigurable: Bool { false }
    static var order: Int { 78 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = FontConfigPlugin()

    // MARK: - UI Contributions

    /// 在状态栏右侧显示字体配置入口
    @MainActor func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        guard activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(FontStatusBarView())
    }
}
