import MagicKit
import SwiftUI

/// 聊天工具栏插件：新建对话、自动批准开关
actor AgentChatToolbarPlugin: SuperPlugin {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = false

    static let id = "AgentChatToolbar"
    static let displayName = String(localized: "Chat Toolbar", table: "AgentChatToolbar")
    static let description = String(localized: "New chat and auto-approve in header", table: "AgentChatToolbar")
    static let iconName = "bubble.left.and.bubble.right"
    static var order: Int { 82 }
    static let enable: Bool = true

    static let shared = AgentChatToolbarPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRightHeaderView() -> AnyView? { nil }

    @MainActor
    func addRightHeaderLeadingView() -> AnyView? { nil }

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [
            AnyView(NewChatButton()),
            AnyView(AutoApproveToggle()),
        ]
    }
}
