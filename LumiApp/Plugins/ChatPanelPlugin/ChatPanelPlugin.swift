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
