import ProviderChatSection

/// 会话区上下文所需的最小能力。
@MainActor
public protocol MessageListChatSectionCapability: AnyObject {
    var activeContext: ChatContext? { get }
}

@MainActor
public final class MessageListChatSectionCapabilityAdapter: MessageListChatSectionCapability {
    private let chat: any ChatSectionProviding
    public init(chat: any ChatSectionProviding) { self.chat = chat }
    public var activeContext: ChatContext? { chat.activeContext }
}