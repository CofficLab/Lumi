import MagicKit
import SwiftUI

/// 语言切换插件
///
/// 在工具栏右侧提供语言选择器（LanguageSelector）。
actor AgentLanguagePlugin: SuperPlugin {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = false
    static let id = "AgentLanguageHeader"
    static let displayName = String(localized: "Language Selector", table: "AgentLanguageHeader")
    static let description = String(localized: "AI response language in header", table: "AgentLanguageHeader")
    static let iconName = "globe"
    static var order: Int { 83 }
    
    /// 核心功能，禁止用户配置
    static var isConfigurable: Bool { false }
    
    static let enable: Bool = true

    static let shared = AgentLanguagePlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Toolbar Views

    /// 工具栏右侧：语言选择器
    @MainActor
    func addToolBarTrailingView() -> AnyView? {
        AnyView(LanguageSelector())
    }
}
