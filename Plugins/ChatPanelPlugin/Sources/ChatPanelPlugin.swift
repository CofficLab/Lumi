import SwiftUI
import LumiCoreKit
import LumiUI
import SuperLogKit
import os

/// Chat workspace panel.
///
/// Provides a dedicated activity-bar entry whose content is the conversation list.
/// The chat message/input surface is still contributed by the existing sidebar
/// plugins when this panel is active.
public actor ChatPanelPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-panel")

    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose: Bool = true
    public static let id = "ChatPanel"
    public static let displayName = String(localized: "Chat", table: "AgentChat")
    public static let description = String(localized: "Conversation list with chat surface", table: "AgentChat")
    public static let iconName = "bubble.left.and.bubble.right.fill"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 78 }
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = ChatPanelPlugin()

    public nonisolated var instanceLabel: String { Self.id }

    @MainActor
    public func addPosterViews() -> [AnyView] {
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
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName, showsProjectToolbar: true, supportsAIChat: true) {
            AnyView(ChatPanelView())
        }
    }
}

public struct ChatPanelView: View {
    public var body: some View {
        AppEmptyState(
            icon: ChatPanelPlugin.iconName,
            title: ChatPanelPlugin.displayName
        )
        .frame(minWidth: 260, idealWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
    }
}
