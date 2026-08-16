import KernelCore
import LumiUI
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderMessageStreaming
import ProviderToolManager
import SwiftUI

@MainActor
public final class MessageListPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.message-list"
    public let order = 82
    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else { return }
        let services = MessageListServices(
            conversations: kernel.resolveProvider((any ConversationManaging).self),
            messages: kernel.resolveProvider((any MessageManaging).self),
            rendering: kernel.resolveProvider((any MessageRenderingProviding).self),
            sender: kernel.resolveProvider((any MessageSendingProviding).self),
            streaming: kernel.resolveProvider((any MessageStreamingProviding).self),
            toolManager: kernel.resolveProvider((any ToolManagerProviding).self),
            agentTurn: kernel.resolveProvider((any AgentLoopProviding).self)
        )
        chat.addItems([ChatSectionItem(id: id, order: 100, fillsRemainingHeight: true) {
            ListView(services: services)
        }])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?.removeItem(id: id)
    }
}
