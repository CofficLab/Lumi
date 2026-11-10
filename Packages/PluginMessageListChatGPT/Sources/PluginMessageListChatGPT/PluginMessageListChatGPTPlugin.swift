import os
import KernelCore
import LumiLoggingKit
import LumiUI
import ProviderChatSection
import ProviderConversation
import SwiftUI

@MainActor
public final class PluginMessageListChatGPTPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.message-list.chatgpt",
        category: "MessageListChatGPT"
    )

    public let id = "com.coffic.lumi.plugin.message-list.chatgpt"
    public let order = 82

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.message-list.chatgpt",
        name: "消息列表（ChatGPT）",
        description: "V5 ChatGPT 风格消息列表",
        category: .chat,
        stage: .preview,
        policy: .alwaysOn
    )

    private var verbosityObservation: ChatGPTVerbosityObservationBox?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding from kernel")
            return
        }
        let conversations = kernel.resolveProvider((any ConversationManaging).self)
        verbosityObservation = ChatGPTVerbosityObservationBox(
            conversations: conversations,
            chat: chat,
            pluginID: id,
            order: order,
            expectedVerbosity: .chatGPT,
            makeView: { AnyView(ChatGPTListView()) }
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        verbosityObservation?.cancel()
        verbosityObservation = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: id)
    }
}
