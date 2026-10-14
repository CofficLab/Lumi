import Foundation
import ProviderMessageSender

/// 建议卡片按钮需要的最小发送能力。
///
/// 收窄 `MessageSendingProviding`：卡片只需要「向指定对话发送一条消息并自动开始回合」。
@MainActor
protocol NewChatStarting: AnyObject {
    /// 在指定对话中发送一条消息，并等待对应回合执行结束。
    ///
    /// 与 `MessageSendingProviding.sendMessage(_:conversationID:)` 语义一致：
    /// 消息落库后由 AgentLoop 自动开始回合。
    func startIn(conversationID: UUID, content: String) async
}

/// 将内核 `MessageSendingProviding` 收窄为 `NewChatStarting`。
@MainActor
final class NewChatStartingAdapter: NewChatStarting {
    private weak var sender: (any MessageSendingProviding)?

    init(sender: (any MessageSendingProviding)?) {
        self.sender = sender
    }

    func startIn(conversationID: UUID, content: String) async {
        guard let sender else { return }
        try? await sender.sendMessage(content, conversationID: conversationID)
    }
}
