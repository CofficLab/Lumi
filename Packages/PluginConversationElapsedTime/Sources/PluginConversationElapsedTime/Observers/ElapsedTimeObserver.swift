import Foundation
import ProviderConversation
import ProviderMessage

/// 监听会话选择与消息变化，把「当前会话 + 需要刷新」的事件转发给状态对象。
///
/// 观察者只负责事件转发，聚合计算交给 ViewModel／状态层。
@MainActor
final class ElapsedTimeObserver {
    private var conversationHandle: (any SelectedConversationObserverHandle)?
    private var messageChangeHandle: (any MessageChangeObserverHandle)?

    init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        onConversationChange: @escaping (UUID?) -> Void,
        onMessageChange: @escaping (UUID) -> Void
    ) {
        onConversationChange(conversations.selectedConversationID)
        conversationHandle = conversations.addSelectedConversationObserver { newID in
            onConversationChange(newID)
        }
        messageChangeHandle = messages.addMessageChangeObserver { change in
            switch change {
            case let .inserted(_, conversationID),
                 let .persisted(_, conversationID),
                 let .updated(conversationID),
                 let .deleted(_, conversationID),
                 let .cleared(conversationID):
                onMessageChange(conversationID)
            }
        }
    }

    func cancel() {
        conversationHandle?.cancel()
        conversationHandle = nil
        messageChangeHandle?.cancel()
        messageChangeHandle = nil
    }
}
