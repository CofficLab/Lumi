import Foundation
import KernelCore
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import KitSuperLog

/// 消息发送装配插件。
@MainActor
public final class MessageSenderPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-sender", category: "MessageSender")

    public let id = "com.coffic.lumi.plugin.message-sender"
    public let order = 9
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.message-sender",
        name: "Message Sender",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .required
    )

    private var agentLoopObserver: (any AgentLoopObserverHandle)?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self),
              let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ConversationManaging, MessageManaging, AgentLoopProviding from kernel")
            return
        }

        let sender = LumiMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: agentLoop
        )
        try kernel.registerProvider((any MessageSendingProviding).self, sender)

        agentLoopObserver = agentLoop.addAgentLoopObserver { [weak sender] event in
            sender?.handleAgentLoopEvent(event)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        agentLoopObserver?.cancel()
        agentLoopObserver = nil
    }
}
