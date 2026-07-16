import LumiChatKit
import LumiCoreKit

struct LanguageChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        updated.systemPromptFragments.append(
            LumiConversationPromptDefaults.fragment(for: context.conversationLanguage)
        )
        return updated
    }
}
