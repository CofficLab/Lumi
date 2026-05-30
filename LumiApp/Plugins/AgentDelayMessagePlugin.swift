import AgentToolKit
import LumiCoreKit
import PluginAgentDelayMessage
import SuperLogKit
import SwiftUI
import os

actor AgentDelayMessagePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = PluginAgentDelayMessage.DelayMessagePlugin.logger
    nonisolated static let emoji = PluginAgentDelayMessage.DelayMessagePlugin.emoji
    nonisolated static let verbose = PluginAgentDelayMessage.DelayMessagePlugin.verbose
    static let id = PluginAgentDelayMessage.DelayMessagePlugin.id
    static let displayName = PluginAgentDelayMessage.DelayMessagePlugin.displayName
    static let description = PluginAgentDelayMessage.DelayMessagePlugin.description
    static let iconName = PluginAgentDelayMessage.DelayMessagePlugin.iconName
    static var category: PluginCategory {
        PluginCategory(package: PluginAgentDelayMessage.DelayMessagePlugin.category)
    }
    static var order: Int { PluginAgentDelayMessage.DelayMessagePlugin.order }
    nonisolated var instanceLabel: String { Self.id }
    static let shared = AgentDelayMessagePlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(DelayMessageOverlay(content: content()))
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [PluginAgentDelayMessage.DelayMessageTool()]
    }
}

@MainActor
private struct DelayMessageOverlay<Content: View>: View, SuperLog {
    nonisolated static var emoji: String { "⏳" }
    nonisolated static var verbose: Bool { AgentDelayMessagePlugin.verbose }
    nonisolated static var logger: Logger { AgentDelayMessagePlugin.logger }

    let content: Content

    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var messageQueueVM: WindowMessageQueueVM

    @State private var hasAppeared = false

    var body: some View {
        content
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                syncAll()
            }
            .onChange(of: conversationVM.selectedConversationId) { _, newId in
                DelayMessageState.shared.syncConversationId(newId)
            }
    }

    private func syncAll() {
        DelayMessageState.shared.syncEnqueueHandler { conversationId, content in
            let message = ChatMessage(
                role: .user,
                conversationId: conversationId,
                content: content
            )
            messageQueueVM.enqueueMessage(message)
        }
        DelayMessageState.shared.syncConversationId(conversationVM.selectedConversationId)

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 已同步 VM 引用到 DelayMessageState")
        }
    }
}
