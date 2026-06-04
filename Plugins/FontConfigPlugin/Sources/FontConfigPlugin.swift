import SwiftUI
import LumiUI
import SuperLogKit
import LumiCoreKit

/// 字体配置插件：在状态栏提供编辑器字体快速切换入口
public actor FontConfigPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let emoji = "🔤"
    public static var category: PluginCategory { .theme }
    public nonisolated static let verbose: Bool = true

    public static let id: String = "FontConfig"
    public static let displayName: String = String(localized: "Font Config", bundle: .module)
    public static let description: String = String(localized: "Quick font switching in status bar", bundle: .module)
    public static let iconName: String = "textformat"
    public static var order: Int { 78 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = FontConfigPlugin()

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        FontConfigViewModel.applyFontNameHandler = { fontName in
            context.applyEditorFontName(fontName, PluginContext())
        }
    }

    // MARK: - UI Contributions

    @MainActor
    public func addPosterViews() -> [AnyView] {
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
    @MainActor public func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        // 字体设置在编辑器可见或 ChatPanel 激活时显示
        guard context.isEditorVisible || context.activeIcon == "bubble.left.and.bubble.right.fill" else { return nil }
        return AnyView(FontStatusBarView())
    }
}
