import MagicKit
import SwiftUI

/// 新建对话头部插件
///
/// 在工具栏右侧提供新建对话按钮（NewChatButton）。
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

    // MARK: - Toolbar Views

    /// 工具栏右侧：新建对话按钮
    @MainActor
    func addToolBarTrailingView(activeIcon: String?) -> AnyView? {
        AnyView(NewChatButton())
    }
}
