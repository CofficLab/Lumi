import SwiftUI
import LumiCoreKit

/// 字体配置插件：在状态栏提供编辑器字体快速切换入口
actor FontConfigPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🔤"
    static var category: PluginCategory { .theme }
    nonisolated static let verbose: Bool = true

    static let id: String = "FontConfig"
    static let displayName: String = String(
        localized: "Font Config", table: "FontConfig")
    static let description: String = String(
        localized: "Quick font switching in status bar", table: "FontConfig")
    static let iconName: String = "textformat"
    static var order: Int { 78 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = FontConfigPlugin()

    // MARK: - UI Contributions

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "字体快速切换",
                subtitle: "在状态栏切换编辑器和聊天字体，适配不同阅读场景。",
                icon: Self.iconName,
                accent: .indigo,
                metrics: [
                    PluginPosterSupport.metric("Aa", "字体"),
                    PluginPosterSupport.metric("Status", "状态栏"),
                ],
                rows: ["编辑器字体", "聊天字体", "快速入口"],
                chips: ["主题", "字体", "状态栏"]
            ),
        ]
    }

    /// 在状态栏右侧显示字体配置入口
    @MainActor func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        // 字体设置在编辑器可见或 ChatPanel 激活时显示
        guard context.isEditorVisible || context.activeIcon == ChatPanelPlugin.iconName else { return nil }
        return AnyView(FontStatusBarView())
    }
}
