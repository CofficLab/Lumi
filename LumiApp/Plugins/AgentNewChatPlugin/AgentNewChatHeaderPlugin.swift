import MagicKit
import SwiftUI

/// 新建对话头部插件
///
/// 注意：新建对话按钮（NewChatButton）已整合到 EditorPlugin 的聊天栏头部。
/// 本插件保留仅用于维护新建对话相关的逻辑。
/// 实际 UI 渲染由 EditorPlugin 的 ChatSidebarView 负责。
actor AgentNewChatHeaderPlugin: SuperPlugin {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose: Bool = false
    static let id = "AgentChatToolbar"
    static let displayName = String(localized: "New Chat Button", table: "AgentNewChat")
    static let description = String(localized: "Create new chat from header", table: "AgentNewChat")
    static let iconName = "bubble.left.and.bubble.right"
    static var order: Int { 60 }
    
    /// 核心功能按钮，禁止用户配置
    static var isConfigurable: Bool { false }
    
    static let enable: Bool = true

    static let shared = AgentNewChatHeaderPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}
}
