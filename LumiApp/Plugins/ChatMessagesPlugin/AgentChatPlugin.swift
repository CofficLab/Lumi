import SwiftUI
import os

/// Agent 聊天插件
///
/// 负责右侧栏的消息列表 Section，显示当前会话的聊天消息时间线。
actor AgentChatPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-chat")

    nonisolated static let emoji = "💬"
    nonisolated static let verbose: Bool = true
    static let id = "AgentChat"
    static let displayName = String(localized: "Agent Chat", table: "AgentChat")
    static let description = String(localized: "Agent chat messages timeline", table: "AgentChat")
    static let iconName = "text.bubble.fill"
    static var category: PluginCategory { .agent }
    static var order: Int { 82 }
    nonisolated static let enable: Bool = true
    static let shared = AgentChatPlugin()

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

    // MARK: - UI Contributions

    /// 右侧栏 Section：消息列表
    @MainActor func addSidebarSections(activeIcon: String?) -> [AnyView] {
        guard ChatSurfaceActivation.isActive(activeIcon) else { return [] }
        return [AnyView(ChatMessagesView())]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
