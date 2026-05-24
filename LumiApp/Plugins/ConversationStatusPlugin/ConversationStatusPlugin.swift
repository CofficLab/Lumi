import SwiftUI
import os

/// 会话状态插件
///
/// 负责右侧栏的状态消息 Section，显示当前会话的发送/流式/工具执行状态。
actor ConversationStatusPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-status")

    nonisolated static let emoji = "🔄"
    nonisolated static let verbose: Bool = true
    static let id = "ConversationStatus"
    static let displayName = String(localized: "Conversation Status", table: "ConversationStatus")
    static let description = String(localized: "Conversation send/streaming/tool execution status", table: "ConversationStatus")
    static let iconName = "arrow.triangle.2.circlepath"
    static var category: PluginCategory { .agent }
    static var order: Int { 83 } // 在ChatMessagesPlugin之后
    nonisolated static let enable: Bool = true
    static let shared = ConversationStatusPlugin()

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

    /// 右侧栏 Section：状态消息
    @MainActor func addSidebarSections(activeIcon: String?) -> [AnyView] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [AnyView(ConversationStatusView())]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}