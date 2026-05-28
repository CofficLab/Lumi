import SwiftUI
import os

/// Chat workspace panel.
///
/// Provides a dedicated activity-bar entry whose content is the conversation list.
/// The chat message/input surface is still contributed by the existing sidebar
/// plugins when this panel is active.
actor ChatPanelPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-panel")

    nonisolated static let emoji = "💬"
    nonisolated static let verbose: Bool = true
    static let id = "ChatPanel"
    static let displayName = String(localized: "Chat", table: "AgentChat")
    static let description = String(localized: "Conversation list with chat surface", table: "AgentChat")
    static let iconName = "bubble.left.and.bubble.right.fill"
    static var category: PluginCategory { .agent }
    static var order: Int { 78 }
    nonisolated static let policy: PluginPolicy = .optIn
    static let shared = ChatPanelPlugin()

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "聊天工作区",
                subtitle: "把会话列表和 AI 聊天表面作为独立活动栏入口。",
                icon: Self.iconName,
                accent: .purple,
                metrics: [
                    PluginPosterSupport.metric("Chat", "会话"),
                    PluginPosterSupport.metric("AI", "工作区"),
                ],
                rows: ["会话列表", "项目工具栏", "AI Chat 支持"],
                chips: ["Agent", "聊天", "工作区"]
            ),
        ]
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName, showsProjectToolbar: true, supportsAIChat: true) {
            AnyView(ChatPanelView())
        }
    }
}

struct ChatPanelView: View {
    var body: some View {
        ConversationListView()
            .frame(minWidth: 260, idealWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
    }
}
