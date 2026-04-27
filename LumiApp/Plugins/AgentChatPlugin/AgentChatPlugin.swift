import MagicKit
import SwiftUI
import os

/// Agent 聊天插件
actor AgentChatPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-chat")

    nonisolated static let emoji = "💬"
    nonisolated static let verbose: Bool = false
    static let id = "AgentChat"
    static let displayName = String(localized: "Agent Chat", table: "AgentChat")
    static let description = String(localized: "Agent chat messages and input area", table: "AgentChat")
    static let iconName = "text.bubble.fill"
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

    /// 右侧栏视图：消息列表 + 输入区
    @MainActor func addSidebarView() -> AnyView? {
        AnyView(AgentChatSidebarView())
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
