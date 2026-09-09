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
                toolbarState?.setSelectedConversationID(newID)
            },
            onMessageInsert: { [weak toolbarState] conversationID in
                guard conversationID == toolbarState?.selectedConversationID else { return }
                toolbarState?.markMessagesChanged(conversationID: conversationID)
            },
            onLLMChange: { [weak toolbarState] in
                toolbarState?.markLLMChanged()
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
final class ContextSizeToolbarState {
    enum Event {
        case selectedConversationChanged(UUID?)
        case messagesChanged(conversationID: UUID)
        case llmChanged
    }

    protocol ObserverHandle: AnyObject {
        func cancel()
    }

    private final class Handle: ObserverHandle {
        private let cancelAction: () -> Void
        private var isCancelled = false

        init(cancelAction: @escaping () -> Void) {
            self.cancelAction = cancelAction
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            cancelAction()
        }
    }

    private(set) var selectedConversationID: UUID?
    private var observers: [UUID: (Event) -> Void] = [:]

    @discardableResult
    func addObserver(_ callback: @escaping (Event) -> Void) -> any ObserverHandle {
        let id = UUID()
        observers[id] = callback
        return Handle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func setSelectedConversationID(_ id: UUID?) {
        guard selectedConversationID != id else { return }
        selectedConversationID = id
        notify(.selectedConversationChanged(id))
    }

    func markMessagesChanged(conversationID: UUID) {
        notify(.messagesChanged(conversationID: conversationID))
    }

    func markLLMChanged() {
        notify(.llmChanged)
    }

    private func notify(_ event: Event) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}
