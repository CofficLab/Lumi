import Combine
import Foundation

/// 当前选中对话的实时状态数据源。
///
/// 消息列表尾部只消费这个 ViewModel；外部 Provider 的变化由插件 observer
/// 转换后写入这里，View 不直接读取会话状态或流式状态 Provider。
@MainActor
final class ConversationStateViewModel: ObservableObject {
    @Published private(set) var activity: AgentActivityProjection?

    private(set) var selectedConversationID: UUID?

    func updateSelectedConversation(_ conversationID: UUID?) {
        guard selectedConversationID != conversationID else { return }
        selectedConversationID = conversationID
        update(activity: nil, for: conversationID)
    }

    func update(
        activity: AgentActivityProjection?,
        for conversationID: UUID?
    ) {
        guard selectedConversationID == conversationID else { return }
        guard self.activity != activity else { return }
        self.activity = activity
    }
}
