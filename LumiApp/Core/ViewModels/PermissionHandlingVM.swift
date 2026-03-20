import Foundation

/// 仅负责处理“工具执行权限请求”的批准/拒绝逻辑。
@MainActor
final class PermissionHandlingVM: ObservableObject {
    private let runtimeStore: ConversationRuntimeStore
    private let conversationVM: ConversationVM
    private let conversationTurnViewModel: ConversationTurnVM
    private let messageViewModel: MessagePendingVM
    private let projectVM: ProjectVM
    private let uiHandler: AgentUIHandler

    init(
        runtimeStore: ConversationRuntimeStore,
        conversationVM: ConversationVM,
        conversationTurnViewModel: ConversationTurnVM,
        messageViewModel: MessagePendingVM,
        projectVM: ProjectVM,
        uiHandler: AgentUIHandler
    ) {
        self.runtimeStore = runtimeStore
        self.conversationVM = conversationVM
        self.conversationTurnViewModel = conversationTurnViewModel
        self.messageViewModel = messageViewModel
        self.projectVM = projectVM
        self.uiHandler = uiHandler
    }

    func respondToPermissionRequest(allowed: Bool) async {
        guard let conversationId = conversationVM.selectedConversationId,
              let request = runtimeStore.pendingPermissionByConversation[conversationId]
        else { return }

        runtimeStore.pendingPermissionByConversation[conversationId] = nil
        uiHandler.setPendingPermissionRequest(nil, conversationId: conversationId)
        runtimeStore.updateRuntimeState(for: conversationId)

        if allowed {
            // 批准后继续执行工具
            Task {
                await conversationTurnViewModel.executeToolAndContinue(
                    request.toToolCall(),
                    conversationId: conversationId,
                    languagePreference: projectVM.languagePreference
                )
            }
            return
        }

        // 拒绝执行：记录一条拒绝消息，并让运行态回到正确状态
        let rejectMessage = ChatMessage(
            role: .tool,
            content: "用户拒绝了执行 \(request.toolName) 的权限请求",
            toolCallID: request.toolCallID
        )

        if conversationVM.selectedConversationId == conversationId {
            messageViewModel.appendMessage(rejectMessage)
        }

        await conversationVM.saveMessage(rejectMessage, to: conversationId)
        runtimeStore.updateRuntimeState(for: conversationId)
    }
}

