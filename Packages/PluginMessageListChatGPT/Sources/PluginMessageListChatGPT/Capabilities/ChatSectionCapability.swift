import ProviderChatSection

/// 会话区上下文所需的最小能力。
@MainActor
protocol MessageListChatSectionCapability: AnyObject {
    var activeContext: ChatContext? { get }
}

@MainActor
final class MessageListChatSectionCapabilityAdapter: MessageListChatSectionCapability {
    private let chat: any ChatSectionProviding

    init(chat: any ChatSectionProviding) {
        self.chat = chat
    }

    var activeContext: ChatContext? { chat.activeContext }
}
