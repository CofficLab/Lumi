import os
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import KitSuperLog
import SwiftUI

/// 会话消息计数插件
///
/// 在 Chat 工具栏显示当前对话的消息数量。
///
/// 复刻自旧版 `Plugins/ConversationMessageCountPlugin`：
/// - 通过 `MessageManaging.messageCount(for:)` 获取消息数
/// - 通过 `ConversationManaging.addSelectedConversationObserver` 监听会话切换
/// - 通过 `MessageManaging.addMessageInsertedObserver` 监听新消息
@MainActor
public final class ConversationMessageCountPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-message-count", category: "ConversationMessageCount")

    public let id = "com.coffic.lumi.plugin.conversation-message-count"
    public let order = 84
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-message-count",
        name: "Conversation Message Count",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    private let toolbarState = MessageCountToolbarState()
    private var observer: MessageCountObserver?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve required providers")
            return
        }

        observer?.cancel()
        observer = MessageCountObserver(
            conversations: conversations,
            messages: messages,
            onConversationChange: { [weak toolbarState] newID in
                toolbarState?.setSelectedConversationID(newID)
            },
            onMessageInsert: { [weak toolbarState] conversationID in
                guard conversationID == toolbarState?.selectedConversationID else { return }
                toolbarState?.markMessagesChanged(conversationID: conversationID)
            }
        )

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: 84,
                placement: .toolbarLeading
            ) {
                MessageCountToolbarView(
                    messages: messages,
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
final class MessageCountToolbarState {
    enum Event {
        case selectedConversationChanged(UUID?)
        case messagesChanged(conversationID: UUID)
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

    private func notify(_ event: Event) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}
