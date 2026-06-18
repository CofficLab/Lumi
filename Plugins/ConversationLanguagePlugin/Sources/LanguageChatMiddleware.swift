import LumiCoreKit

struct LanguageChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        updated.systemPromptFragments.append(context.conversationLanguage.systemPromptFragment)
        return updated
    }
}
