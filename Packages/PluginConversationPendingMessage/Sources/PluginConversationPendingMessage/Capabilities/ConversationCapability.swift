import Foundation
import ProviderConversation

/// 待发消息功能所需的最小会话选择能力。
@MainActor
protocol PendingMessageConversationCapability: AnyObject {
    var selectedConversationID: UUID? { get }

    @discardableResult
    func addObserver(
        _ callback: @escaping (UUID?) -> Void
    ) -> any PendingMessageConversationObserverHandle
}

@MainActor
protocol PendingMessageConversationObserverHandle: AnyObject {
    func cancel()
}

/// 将会话 Provider 收窄为 pending 插件自己的 capability。
@MainActor
final class PendingMessageConversationCapabilityAdapter: PendingMessageConversationCapability {
    private final class ObserverHandle: PendingMessageConversationObserverHandle {
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

    private let conversations: any ConversationManaging

    init(conversations: any ConversationManaging) {
        self.conversations = conversations
    }

    var selectedConversationID: UUID? {
        conversations.selectedConversationID
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (UUID?) -> Void
    ) -> any PendingMessageConversationObserverHandle {
        let handle = conversations.addSelectedConversationObserver(callback)
        return ObserverHandle {
            handle.cancel()
        }
    }
}
