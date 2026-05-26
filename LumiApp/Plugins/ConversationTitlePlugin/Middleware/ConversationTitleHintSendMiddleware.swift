import AgentToolKit
import Foundation
import LLMKit

/// 对话标题提示中间件
///
/// 在每次发送用户消息前，将当前对话标题注入到 transientSystemPrompts 中，
/// 并指导 LLM 在话题偏离标题时调用 `update_conversation_title` 工具更新标题。
///
/// ## 工作流程
/// 1. 获取当前对话的标题
/// 2. 将标题和提示词注入到 transientSystemPrompts
/// 3. LLM 接收到提示后，如发现话题偏离，可调用工具更新标题
@MainActor
final class ConversationTitleHintSendMiddleware: SuperSendMiddleware, SuperLog {
    nonisolated static let emoji = "🏷️"
    nonisolated static let verbose: Bool = true
    let id: String = "conversation-title-hint"
    let order: Int = 5  // 在基础上下文注入之后执行

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        guard let conversation = ctx.chatHistoryService.fetchConversation(id: ctx.conversationId) else {
            await next(ctx)
            return
        }

        let title = conversation.displayTitle
        let language = ctx.projectVM.languagePreference

        let prompt = Self.buildHintPrompt(currentTitle: title, language: language)
        ctx.transientSystemPrompts.append(prompt)

        if Self.verbose {
            AppLogger.core.debug("\(Self.t)🏷️ 已注入对话标题提示: \"\(title)\"")
        }

        await next(ctx)
    }

    // MARK: - 提示词构建

    private static func buildHintPrompt(currentTitle: String, language: LanguagePreference) -> String {
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
