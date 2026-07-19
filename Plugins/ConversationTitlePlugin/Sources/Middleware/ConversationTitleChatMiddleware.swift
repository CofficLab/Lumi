import LumiKernel

struct ConversationTitleChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let title = context.conversationTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return updated
        }

        updated.systemPromptFragments.append(
            Self.buildHintPrompt(currentTitle: title, language: context.conversationLanguage)
        )
        return updated
    }

    private static func buildHintPrompt(currentTitle: String, language: LumiConversationLanguage) -> String {
        switch language {
        case .chinese:
            return """
            ## 对话标题管理

            当前对话标题为：「\(currentTitle)」

            在回复用户之前，请判断当前对话的主题是否仍然符合这个标题。
            如果话题已经明显偏离原标题，请调用 `update_conversation_title` 工具将标题更新为能准确反映当前讨论内容的新标题。

            标题要求：
            - 简洁明了，不超过 20 个字符
            - 准确反映用户当前讨论的核心主题
            - 不要使用标点符号
            """
        case .english:
            return """
            ## Conversation Title Management

            The current conversation title is: "\(currentTitle)"

            Before responding, please evaluate whether the current conversation topic still aligns with this title.
            If the topic has clearly drifted from the original title, call the `update_conversation_title` tool to update it to a new title that accurately reflects the current discussion.

            Title requirements:
            - Concise and clear, no more than 20 characters
            - Accurately reflects the core topic the user is currently discussing
            - No punctuation
            """
        }
    }
}
