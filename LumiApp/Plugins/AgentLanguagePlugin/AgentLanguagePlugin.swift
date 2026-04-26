import MagicKit
import SwiftUI

/// 语言切换插件
///
/// 注意：语言选择器（LanguageSelector）已整合到 EditorPlugin 的聊天栏头部。
/// 本插件保留仅用于维护语言偏好相关的数据逻辑。
/// 实际 UI 渲染由 EditorPlugin 的 ChatSidebarView 负责。
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
}
