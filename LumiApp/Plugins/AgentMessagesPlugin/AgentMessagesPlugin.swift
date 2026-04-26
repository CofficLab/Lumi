import MagicKit
import SwiftUI

/// 消息插件 - 负责显示聊天消息列表
///
/// 注意：消息列表视图（ChatMessagesView、MessageListView 等）已整合到 EditorPlugin
/// 的右侧聊天栏中。本插件保留仅用于维护聊天消息相关的 ViewModel 和数据管理。
/// 实际 UI 渲染由 EditorPlugin 的 ChatSidebarView 负责。
actor AgentMessagesPlugin: SuperPlugin {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose: Bool = false
    static let id = "DevAssistantMessages"
    static let displayName = String(localized: "Dev Assistant Messages", table: "AgentMessages")
    static let description = String(localized: "DevAssistant chat messages", table: "AgentMessages")
    static let iconName = "text.bubble.fill"
    static var order: Int { 82 }
    static let enable: Bool = true

    static let shared = AgentMessagesPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        // Init
    }

    nonisolated func onEnable() {
        // Init
    }

    nonisolated func onDisable() {
        // Cleanup
    }
}

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
