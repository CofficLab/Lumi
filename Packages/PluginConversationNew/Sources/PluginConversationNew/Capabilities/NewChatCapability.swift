import ProviderConversation

/// 新会话按钮所需的最小会话管理能力。
@MainActor
protocol NewChatCapability: AnyObject {
    /// 取消当前会话选择（会话面板会按需展示新建会话入口）。
    func deselectConversation()
}

/// 将 Kernel 的 ConversationManaging Provider 适配为插件能力。
@MainActor
final class NewChatCapabilityAdapter: NewChatCapability {
    private weak var conversations: (any ConversationManaging)?

    init(conversations: any ConversationManaging) {
        self.conversations = conversations
    }

    func deselectConversation() {
        conversations?.deselectConversation()
    }
}
