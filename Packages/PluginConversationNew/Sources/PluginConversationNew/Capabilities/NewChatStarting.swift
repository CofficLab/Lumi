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
        // 只发送工具参数里自包含的 task 文本，必须走显式空附件入口：隐式
        // sendMessage 会快照全局挂起池，把当前对话输入框里未发送的附件带进
        // 新对话的首条消息并清空输入框，附件可能落到另一个项目/模型上下文（#591）。
        try? await sender.sendMessage(
            content,
            imageAttachments: [],
            fileAttachments: [],
            conversationID: conversationID
        )
    }
}
