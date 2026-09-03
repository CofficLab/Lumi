import os
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderLLMManager
import ProviderLLMVendors
import ProviderMessage
import KitSuperLog
import SwiftUI

/// 上下文窗口大小插件。
///
/// 在 Chat 工具栏显示当前模型的上下文窗口大小和最近一次请求的输入 token 数。
@MainActor
public final class ConversationContextSizePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-context-size",
        category: "ConversationContextSize"
    )

    public let id = "com.coffic.conversation-context-size"
    public let order = 85
    public let metadata = PluginMetadata(
        id: "com.coffic.conversation-context-size",
        name: "Conversation Context Size",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .required
    )

    private let toolbarState = ContextSizeToolbarState()
    private var observer: ContextSizeObserver?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self),
              let llmManager = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve required providers")
            return
        }

        observer?.cancel()
        observer = ContextSizeObserver(
            conversations: conversations,
            messages: messages,
            llmManager: llmManager,
            onConversationChange: { [weak toolbarState] newID in
                toolbarState?.selectedConversationID = newID
            },
            onMessageInsert: { [weak toolbarState] conversationID in
                guard conversationID == toolbarState?.selectedConversationID else { return }
                toolbarState?.messageRefreshRevision &+= 1
            },
            onLLMChange: { [weak toolbarState] in
                toolbarState?.messageRefreshRevision &+= 1
            }
        )

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: order,
                placement: .toolbarLeading
            ) {
                ContextSizeToolbarView(
                    conversations: conversations,
                    messages: messages,
                    llmManager: llmManager,
                    state: self.toolbarState
                )
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        observer?.cancel()
        observer = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar-button")
    }
}

@MainActor
final class ContextSizeToolbarState: ObservableObject {
    @Published var selectedConversationID: UUID?
    @Published var messageRefreshRevision = 0
}
