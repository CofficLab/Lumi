import Foundation
import ProviderConversation

/// 将「对话供应商/模型变更」事件转发给 LLM 管理器插件。
///
/// 仅透传 `providerChanged`：其余事件（选中、创建、删除、列表刷新等）不涉及
/// 对话侧的供应商/模型绑定，无需触发全局选中同步。
@MainActor
final class ConversationProviderObserver {
    private var handle: (any ConversationObserverHandle)?

    init(
        conversations: any ConversationManaging,
        onChange: @escaping (UUID) -> Void
    ) {
        handle = conversations.addConversationObserver { event in
            guard case .providerChanged(let conversationID) = event else { return }
            onChange(conversationID)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
