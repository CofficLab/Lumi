import Foundation
import LumiKernel

@MainActor
enum ConversationTitleService {
    static func generateTitle(userMessage: String, conversationID: UUID) async -> String? {
        guard let chatService = ConversationTitleRuntimeBridge.chatServiceProvider?() else {
            return nil
        }

        guard let model = chatService.modelName(for: conversationID) ?? chatService.selectedModel else {
            return String(userMessage.prefix(20))
        }

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
            let response = try await chatService.generateEphemeralCompletion(
                messages: [
                    LumiChatMessage(conversationID: conversationID, role: .user, content: titlePrompt),
                ],
                model: model,
                conversationID: conversationID
            )
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
