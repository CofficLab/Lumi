import Foundation
import ProviderMessageSender

/// 待发消息功能所需的最小发送能力。
@MainActor
protocol PendingMessageSendingCapability: AnyObject {
    func pendingMessages(for conversationID: UUID) -> [PendingChatMessage]
    func cancelPendingMessage(id: UUID, in conversationID: UUID)

    @discardableResult
    func addObserver(
        _ callback: @escaping (PendingMessageSendingEvent) -> Void
    ) -> any PendingMessageSendingObserverHandle
}

@MainActor
enum PendingMessageSendingEvent {
    case pendingMessagesChanged(conversationID: UUID)
}

@MainActor
protocol PendingMessageSendingObserverHandle: AnyObject {
    func cancel()
}

/// 将内核发送 Provider 收窄为 pending 插件自己的 capability。
@MainActor
final class PendingMessageSendingCapabilityAdapter: PendingMessageSendingCapability {
    private final class ObserverHandle: PendingMessageSendingObserverHandle {
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

    private let sender: any MessageSendingProviding

    init(sender: any MessageSendingProviding) {
        self.sender = sender
    }

    func pendingMessages(for conversationID: UUID) -> [PendingChatMessage] {
        sender.pendingMessages(for: conversationID)
    }

    func cancelPendingMessage(id: UUID, in conversationID: UUID) {
        sender.cancelPendingMessage(id: id, in: conversationID)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PendingMessageSendingEvent) -> Void
    ) -> any PendingMessageSendingObserverHandle {
        let handle = sender.addMessageSenderObserver { event in
            guard case let .pendingMessagesChanged(conversationID) = event else { return }
            callback(.pendingMessagesChanged(conversationID: conversationID))
        }
        return ObserverHandle {
            handle.cancel()
        }
    }
}
