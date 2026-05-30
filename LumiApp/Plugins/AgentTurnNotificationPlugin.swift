import PluginAgentTurnNotification
import SwiftUI

actor AgentTurnNotificationPlugin: SuperPlugin {
    nonisolated static let logger = PluginAgentTurnNotification.AgentTurnNotificationPlugin.logger
    nonisolated static let emoji = PluginAgentTurnNotification.AgentTurnNotificationPlugin.emoji
    nonisolated static let verbose = PluginAgentTurnNotification.AgentTurnNotificationPlugin.verbose
    static let id = PluginAgentTurnNotification.AgentTurnNotificationPlugin.id
    static let displayName = PluginAgentTurnNotification.AgentTurnNotificationPlugin.displayName
    static let description = PluginAgentTurnNotification.AgentTurnNotificationPlugin.description
    static let iconName = PluginAgentTurnNotification.AgentTurnNotificationPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginAgentTurnNotification.AgentTurnNotificationPlugin.category) }
    static var order: Int { PluginAgentTurnNotification.AgentTurnNotificationPlugin.order }
    static let shared = AgentTurnNotificationPlugin()

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(AgentTurnNotificationBridge(content: content()))
    }
}

@MainActor
private struct AgentTurnNotificationBridge<Content: View>: View {
    let content: Content

    @EnvironmentObject private var conversationVM: WindowConversationVM
    @StateObject private var handler = PluginAgentTurnNotification.AgentTurnNotificationHandler()

    var body: some View {
        content
            .onAgentTurnFinished { conversationId in
                handler.postTurnFinishedNotification(conversationId: conversationId)
            }
            .onAppear {
                handler.bind()
                PluginAgentTurnNotification.AgentTurnNotificationRuntime.selectConversation = { conversationId in
                    conversationVM.setSelectedConversation(
                        conversationId,
                        reason: "agentTurnNotificationTap"
                    )
                }
            }
    }
}
