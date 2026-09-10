import Foundation
import KitLLM
import ProviderConversation
import ProviderLifecycleHooks

/// `willSendToLLM` 钩子：注入当前会话的回复语言指令（中文 / English）。
///
/// 注入的是瞬态 system 消息，不落库。
@MainActor
final class ConversationLanguageHook {
    private weak var conversations: (any ConversationManaging)?

    init(conversations: (any ConversationManaging)?) {
        self.conversations = conversations
    }

    func apply(to context: WillSendToLLMContext) -> WillSendToLLMContext {
        guard let conversations else { return context }
        let language = conversations.language(for: context.conversationID)
        let prompt: String
        switch language {
        case .chinese: prompt = "## 语言偏好\n请用中文回复用户。"
        case .english: prompt = "## Language Preference\nPlease respond in English."
        }
        var ctx = context
        ctx.messages = [LLMMessage(role: .system, content: prompt)] + ctx.messages
        return ctx
    }
}
