import Foundation

/// 处理工具权限浮层：写回 `ToolCall.authorizationState`，多工具依次询问，结束后通知继续发送管线。
@MainActor
final class PermissionHandlingVM: ObservableObject {
    private let permissionRequestViewModel: PermissionRequestVM
    private let chatHistoryService: ChatHistoryService
    private let toolExecutionService: ToolExecutionService

    init(
        permissionRequestViewModel: PermissionRequestVM,
        chatHistoryService: ChatHistoryService,
        toolExecutionService: ToolExecutionService
    ) {
        self.permissionRequestViewModel = permissionRequestViewModel
        self.chatHistoryService = chatHistoryService
        self.toolExecutionService = toolExecutionService
    }

    func respondToPermissionRequest(allowed: Bool) async {
        guard let request = permissionRequestViewModel.pendingPermissionRequest,
              let session = permissionRequestViewModel.pendingToolPermissionSession else { return }

        let messages = chatHistoryService.loadMessages(forConversationId: session.conversationId) ?? []
        guard var assistant = messages.first(where: { $0.id == session.assistantMessageId }),
              var calls = assistant.toolCalls else {
            clearPending()
            return
        }

        guard let idx = calls.firstIndex(where: { $0.id == request.toolCallID }) else {
            clearPending()
            return
        }

        calls[idx].authorizationState = allowed ? .userApproved : .userRejected
        assistant.toolCalls = calls

        _ = await chatHistoryService.updateMessageAsync(assistant, conversationId: session.conversationId)

        permissionRequestViewModel.setPendingPermissionRequest(nil)

        if let next = calls.first(where: { $0.authorizationState.needsAuthorizationPrompt }) {
            let risk = await toolExecutionService.evaluateRisk(toolName: next.name, arguments: next.arguments)
            permissionRequestViewModel.setPendingPermissionRequest(
                PermissionRequest(
                    toolName: next.name,
                    argumentsString: next.arguments,
                    toolCallID: next.id,
                    riskLevel: risk
                )
            )
            return
        }

        permissionRequestViewModel.setPendingToolPermissionSession(nil)
        NotificationCenter.postResumeSendAfterToolPermission(conversationId: session.conversationId)
    }

    private func clearPending() {
        permissionRequestViewModel.setPendingPermissionRequest(nil)
        permissionRequestViewModel.setPendingToolPermissionSession(nil)
    }
}
