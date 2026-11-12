import SwiftUI
import ProviderConversation
import ProviderMessage
import ProviderLLMManager

/// 上下文 toolbar 的统一状态：追踪当前会话和消息变化，通知所有订阅者刷新。
@MainActor
final class ContextToolbarState {
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

/// 订阅会话、消息、LLM 变化并转发给 `ContextToolbarState`。
@MainActor
final class ContextToolbarObserver {
    private var conversationHandle: (any SelectedConversationObserverHandle)?
    private var messageHandle: (any MessageInsertedObserverHandle)?
    private var llmHandle: (any LLMManagerObserverHandle)?

    init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        llmManager: any LLMManaging,
        onConversationChange: @escaping (UUID?) -> Void,
        onMessageInsert: @escaping (UUID) -> Void,
        onLLMChange: @escaping () -> Void
    ) {
        onConversationChange(conversations.selectedConversationID)
        conversationHandle = conversations.addSelectedConversationObserver { id in
            onConversationChange(id)
        }
        messageHandle = messages.addMessageInsertedObserver { _, conversationID in
            onMessageInsert(conversationID)
        }
        llmHandle = llmManager.addObserver { _ in
            onLLMChange()
        }
    }

    func cancel() {
        conversationHandle?.cancel()
        conversationHandle = nil
        messageHandle?.cancel()
        messageHandle = nil
        llmHandle?.cancel()
        llmHandle = nil
    }
}
