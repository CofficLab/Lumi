import Foundation
import KernelCore
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import LumiLoggingKit
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

    private var agentLoopObserver: AgentLoopObserver?
    private var pendingQueuePersistence: PendingQueuePersistence?

    /// 待发队列持久化存储；测试可注入临时文件，避免污染真实 Application Support（#596）。
    var pendingQueueStore = PendingQueueStore()

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self),
              let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ConversationManaging, MessageManaging, AgentLoopProviding from kernel")
            return
        }

        let sender = MessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: agentLoop
        )
        try kernel.registerProvider((any MessageSendingProviding).self, sender)
        agentLoopObserver = AgentLoopObserver(agentLoop: agentLoop, sender: sender)

        // 先恢复上次未排空的待发队列，再订阅变化即时落盘，
        // 保证已提交但尚未发出的消息与附件在重启后不丢失（#596）。
        let persistence = PendingQueuePersistence(store: pendingQueueStore, sender: sender)
        persistence.restore()
        persistence.startObserving()
        pendingQueuePersistence = persistence
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 退出前兜底落盘当前队列，再拆除监听（#596）。
        pendingQueuePersistence?.persist()
        pendingQueuePersistence?.stop()
        pendingQueuePersistence = nil
        agentLoopObserver?.cancel()
        agentLoopObserver = nil
    }
}
