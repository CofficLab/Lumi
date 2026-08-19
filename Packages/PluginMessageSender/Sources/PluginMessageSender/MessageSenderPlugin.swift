import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import os
import SuperLogKit

/// 消息发送装配插件。
///
/// 在 `onBoot` 中解析内核已装配的 `ConversationManaging` / `MessageManaging` /
/// `AgentLoopProviding`，构造插件自带的 `LumiMessageSender`（独立实现
/// `MessageSendingProviding`，不复用 `ProviderMessageSender.DefaultMessageSender`）
/// 并注册，供聊天输入、消息列表、渲染器等消费方共享同一实例。
///
/// 该能力原先由 `FactoryLumi2.ProviderFactory.registerProviders` 直接装配注册；
/// 现改为插件贡献（对齐旧版 `Plugins/MessageSenderPlugin` 的职责），宿主可
/// 通过裁剪/替换插件列表定制该能力。
///
/// 顺序说明：`order = 9` 晚于替换基础 Provider 的插件（`ConversationManagerPlugin`
/// order=7、`MessageManagerPlugin` order=8），确保解析到最终实例；早于所有
/// `MessageSendingProviding` 消费方（`ConversationForkPlugin` order=80 起），
/// 保证其 `onBoot` 能 resolve 到本插件注册的实现。
@MainActor
public final class MessageSenderPlugin: SuperPlugin,SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-sender", category: "MessageSender")

    public let id = "com.coffic.lumi.plugin.message-sender"
    public let order = 9
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.message-sender",
        name: "Message Sender",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

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
    }
}
