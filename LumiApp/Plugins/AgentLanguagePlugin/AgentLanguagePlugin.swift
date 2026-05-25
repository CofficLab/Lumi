import SwiftUI

/// 语言切换插件
///
/// 在右侧栏底部工具栏提供语言切换按钮（LanguageToggleButton），
/// 位于 ChatMode 按钮左侧，点击循环切换中文/英文。
/// 通过中间件自动将语言偏好注入 LLM 系统提示。
actor AgentLanguagePlugin: SuperPlugin {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = true
    static let id = "AgentLanguageHeader"
    static let displayName = String(localized: "Language Selector", table: "AgentLanguageHeader")
    static let description = String(localized: "AI response language in header", table: "AgentLanguageHeader")
    static let iconName = "globe"
    static var category: PluginCategory { .agent }
    static var order: Int { 83 }

    /// 核心功能，禁止用户配置
    static var isConfigurable: Bool { false }

    static let enable: Bool = true

    static let shared = AgentLanguagePlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Send Middlewares

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(LanguageSendMiddleware())]
    }

    // MARK: - Sidebar Toolbar

    /// 右侧栏底部工具栏左侧：语言切换按钮（在 ChatMode 按钮左侧）
    @MainActor
    func addSidebarLeadingToolbarItems(activeIcon: String?) -> [SidebarToolbarItem] {
        guard ChatSurfaceActivation.isActive(activeIcon) else { return [] }
        return [
            SidebarToolbarItem(
                id: "language-toggle",
                title: String(localized: "Language Selector", table: "AgentLanguageHeader"),
                systemImage: "globe",
                priority: 5  // 低于 ChatMode 的 10，排在左侧
            )
        ]
    }

    /// 语言切换按钮的自定义视图
    @MainActor
    func addSidebarToolbarItemView(itemId: String, activeIcon: String?) -> AnyView? {
        guard itemId == "language-toggle" else { return nil }
        return AnyView(LanguageToggleButton())
    }
}
