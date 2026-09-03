import Foundation
import ProviderConversation
import ProviderConversationState
import ProviderMessage
import ProviderMessageStreaming

/// Owns every external Provider subscription used by the message-list plugin.
@MainActor
final class MessageListObserverHub {
    private struct Consumer {
        let onMessageChange: ((MessageChange) -> Void)?
        let onMessagesWillChange: (() -> Void)?
        let onConversationStateChange: (() -> Void)?
        let onStreamingChange: (() -> Void)?
        let onSelectedConversationChange: ((UUID?) -> Void)?
        let onConversationChange: (() -> Void)?
    }

    private let servicesObserver = MessageListServicesObserver()
    private var consumers: [UUID: Consumer] = [:]
    private var selectedConversationHandle: (any SelectedConversationObserverHandle)?
    private var conversationHandle: (any ConversationObserverHandle)?

    init(services: MessageListServices) {
        if let messages = services.messages {
            servicesObserver.bindMessages(
                messages,
                onChange: { [weak self] change in
                    self?.consumers.values.forEach { $0.onMessageChange?(change) }
                },
                onWillChange: { [weak self] in
                    self?.consumers.values.forEach { $0.onMessagesWillChange?() }
                }
            )
        }
        if let conversationState = services.conversationState {
            servicesObserver.bindConversationState(conversationState) { [weak self] in
                self?.consumers.values.forEach { $0.onConversationStateChange?() }
            }
        }
        if let streaming = services.streaming {
            servicesObserver.bindStreaming(streaming) { [weak self] in
                self?.consumers.values.forEach { $0.onStreamingChange?() }
            }
        }
        if let conversations = services.conversations {
            selectedConversationHandle = conversations.addSelectedConversationObserver { [weak self] id in
                self?.consumers.values.forEach { $0.onSelectedConversationChange?(id) }
            }
            conversationHandle = conversations.addConversationObserver { [weak self] _ in
                self?.consumers.values.forEach { $0.onConversationChange?() }
            }
        }
    }

    @discardableResult
    func addConsumer(
        onMessageChange: ((MessageChange) -> Void)? = nil,
        onMessagesWillChange: (() -> Void)? = nil,
        onConversationStateChange: (() -> Void)? = nil,
        onStreamingChange: (() -> Void)? = nil,
        onSelectedConversationChange: ((UUID?) -> Void)? = nil,
        onConversationChange: (() -> Void)? = nil
    ) -> MessageListObserverHubHandle {
        let id = UUID()
        consumers[id] = Consumer(
            onMessageChange: onMessageChange,
            onMessagesWillChange: onMessagesWillChange,
            onConversationStateChange: onConversationStateChange,
            onStreamingChange: onStreamingChange,
            onSelectedConversationChange: onSelectedConversationChange,
            onConversationChange: onConversationChange
        )
        return MessageListObserverHubHandle { [weak self] in
            self?.consumers.removeValue(forKey: id)
        }
    }

    func cancel() {
        consumers.removeAll()
        selectedConversationHandle?.cancel()
        selectedConversationHandle = nil
        conversationHandle?.cancel()
        conversationHandle = nil
        servicesObserver.cancel()
    }
}

@MainActor
final class MessageListObserverHubHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        let cancellation = self.cancellation
        self.cancellation = nil
        cancellation?()
    }

}
