import SwiftUI
import LumiCoreKit
import SuperLogKit
import os

/// LLM 消息发送插件：监听 DB 事件，发送 LLM 并写库。
public actor MessageSenderPlugin: SuperPlugin, SuperLog {
    nonisolated public static let emoji = "📬"
    public static var category: PluginCategory { .agent }
    nonisolated public static let verbose: Bool = false
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-sender")

    nonisolated public static let policy: PluginPolicy = .alwaysOn

    public static let id: String = "MessageSender"
    public static let displayName: String = "Message Sender"
    public static let description: String = "Send Agent messages to LLM providers with streaming and retry"
    public static let iconName: String = "antenna.radiowaves.left.and.right"
    public static var order: Int { 200 }

    nonisolated public var instanceLabel: String { Self.id }
    public static let shared = MessageSenderPlugin()

    private init() {}

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        AgentLLMSender.send = { request, dependencies in
            await SenderService.send(request: request, dependencies: dependencies)
        }

        RuntimeBridge.loadMessages = context.loadMessages
        RuntimeBridge.saveMessage = context.saveMessage
        RuntimeBridge.loadTurnPhase = context.loadTurnPhase
        RuntimeBridge.setTurnPhase = context.setTurnPhase
        RuntimeBridge.tryAcquireConversationLock = context.tryAcquireConversationLock
        RuntimeBridge.releaseConversationLock = context.releaseConversationLock
        RuntimeBridge.isConversationCancelled = context.isConversationCancelled
        RuntimeBridge.prepareMessagesForLLM = context.prepareMessagesForLLM
        RuntimeBridge.makeLLMSendDependencies = context.makeLLMSendDependencies
        RuntimeBridge.evaluateToolPermissions = context.evaluateToolPermissions
        RuntimeBridge.consumeTransientSystemPrompts = context.consumeTransientSystemPrompts
        RuntimeBridge.buildLLMErrorMessage = context.buildLLMErrorMessage
        RuntimeBridge.currentProviderId = context.currentProviderId
        RuntimeBridge.finishAgentTurn = context.finishAgentTurn
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(DatabaseEventObserver(content: content()))
    }
}

private struct DatabaseEventObserver<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .messageSaved)) { notification in
                guard let conversationId = notification.userInfo?["conversationId"] as? UUID else { return }
                SenderOrchestrator.handleMessageSaved(conversationId: conversationId)
            }
            .onReceive(NotificationCenter.default.publisher(for: .agentTurnPhaseChanged)) { notification in
                guard let conversationId = notification.object as? UUID else { return }
                guard notification.userInfo?["phase"] as? String == AgentTurnPhase.processing.rawValue else { return }
                SenderOrchestrator.handleMessageSaved(conversationId: conversationId)
            }
    }
}
