import MagicKit
import SwiftUI

/// 新建对话头部插件：右侧栏 header 中的新建对话按钮
actor AgentNewChatHeaderPlugin: SuperPlugin {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = false

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

    @MainActor
    func addRightHeaderLeadingView() -> AnyView? { nil }

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(NewChatButton())]
    }
}
