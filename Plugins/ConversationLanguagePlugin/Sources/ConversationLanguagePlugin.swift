import LumiCoreKit
import SwiftUI

/// 语言切换插件
///
/// 在右侧栏底部工具栏提供语言切换按钮（LanguageToggleButton），
/// 位于 ChatMode 按钮左侧，点击循环切换中文/英文。
/// 通过中间件自动将语言偏好注入 LLM 系统提示。
public actor ConversationLanguagePlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public nonisolated static let emoji = "🌐"
    public nonisolated static let verbose: Bool = true
    public static let id = "AgentLanguageHeader"
    public static let displayName = String(localized: "Language Selector", bundle: .module)
    public static let description = String(localized: "AI response language in header", bundle: .module)
    public static let iconName = "globe"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 83 }

    /// 核心功能，禁止用户配置

    public static let shared = ConversationLanguagePlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - Send Middlewares

    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(LanguageSendMiddleware())]
    }

    // MARK: - Sidebar Toolbar

    /// 右侧栏底部工具栏左侧：语言切换按钮（在 ChatMode 按钮左侧）
    @MainActor
    public func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        guard context.showChat.isVisible else { return [] }
        return [
            SidebarToolbarItem(
                id: "language-toggle",
                title: String(localized: "Language Selector", bundle: .module),
                systemImage: "globe",
                priority: 5  // 低于 ChatMode 的 10，排在左侧
            )
        ]
    }

    /// 语言切换按钮的自定义视图
    @MainActor
    public func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        guard itemId == "language-toggle" else { return nil }
        guard let languagePreferenceContext = context.languagePreferenceContext else { return nil }
        return AnyView(LanguageToggleButton(languageContext: languagePreferenceContext))
    }
}
