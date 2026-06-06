import Foundation
import LLMKit

/// 无状态的会话标题生成器。
///
/// 输入首条用户消息、LLM 配置和一次性发送函数，输出最终标题；不持有 LLM、
/// 不读取/写入会话存储，也不触发 UI 或通知副作用。
struct ConversationTitleGenerator {
    typealias SendMessage = @Sendable ([ChatMessage], LLMConfig) async throws -> ChatMessage

    func generate(
        userMessage: String,
        config: LLMConfig,
        sendMessage: SendMessage
    ) async -> String {
        let trimmedMessage = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTitle = String(trimmedMessage.prefix(20))

        guard trimmedMessage.count > 15 else {
            return fallbackTitle
        }

        let titlePrompt = """
        请为以下用户消息生成一个简洁的对话标题（最多 10 个中文字符或 15 个英文字符）：

        用户消息：\(trimmedMessage)

        要求：
        - 标题要准确反映用户的核心需求
        - 简洁明了
        - 不要使用标点符号
        - 直接返回标题，不要解释
        """

        do {
            let titleConfig = config

            let titleMessages: [ChatMessage] = [
                ChatMessage(role: .user, conversationId: UUID(), content: titlePrompt),
            ]

            let response = try await sendMessage(titleMessages, titleConfig)
            guard response.role == .assistant else {
                return fallbackTitle
            }

            let generatedTitle = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !generatedTitle.isEmpty else {
                return fallbackTitle
            }

            return String(generatedTitle.prefix(20))
        } catch {
            return fallbackTitle
        }
    }
}
