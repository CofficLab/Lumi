import Foundation
import AgentToolKit

/// 处理消息列表内联工具授权：写回 `ToolCall.authorizationState`，全部处理完后恢复发送管线。
@MainActor
final class WindowPermissionHandlingVM: ObservableObject {
    private let chatHistoryService: ChatHistoryService

    init(chatHistoryService: ChatHistoryService) {
        self.chatHistoryService = chatHistoryService
    }

    func respondToToolPermission(
        conversationId: UUID,
        assistantMessageId: UUID,
        toolCallId: String,
        allowed: Bool
    ) async {
        let messages = chatHistoryService.loadMessages(forConversationId: conversationId) ?? []
        guard var assistant = messages.first(where: { $0.id == assistantMessageId }),
              var calls = assistant.toolCalls else {
            return
        }

        guard let idx = calls.firstIndex(where: { $0.id == toolCallId }) else { return }

        calls[idx].authorizationState = allowed ? .userApproved : .userRejected
        assistant.toolCalls = calls

        _ = await chatHistoryService.updateMessageAsync(assistant, conversationId: conversationId)

        guard !calls.contains(where: { $0.authorizationState.needsAuthorizationPrompt }) else {
            return
        }

        NotificationCenter.postResumeSendAfterToolPermission(conversationId: conversationId)
    }
}
