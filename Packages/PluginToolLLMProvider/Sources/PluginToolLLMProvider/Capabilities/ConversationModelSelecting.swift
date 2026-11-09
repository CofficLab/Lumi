import Foundation
import ProviderConversation

/// 卡片把模型写回所属会话所需的最小能力。
///
/// 只暴露一个按会话 ID 写入的方法，避免把整个 `ConversationManaging`
/// 带进视图模型与测试。
@MainActor
protocol ConversationModelSelecting: AnyObject {
    func selectProvider(id: String, model: String?, for conversationID: UUID)
}

/// 把内核的会话管理收窄为卡片需要的写入口。
@MainActor
final class ConversationModelSelectionAdapter: ConversationModelSelecting {
    private let conversations: any ConversationManaging

    init(conversations: any ConversationManaging) {
        self.conversations = conversations
    }

    func selectProvider(id: String, model: String?, for conversationID: UUID) {
        conversations.selectProvider(id: id, model: model, for: conversationID)
    }
}
