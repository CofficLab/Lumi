import Foundation

/// 仅负责处理“工具执行权限请求”的批准/拒绝逻辑。
@MainActor
final class PermissionHandlingVM: ObservableObject {
    private let runtimeStore: ConversationRuntimeStore
    private let conversationVM: ConversationVM
    private let conversationTurnPipelineHandler: ConversationTurnPipelineHandler
    private let permissionRequestViewModel: PermissionRequestVM

    init(
        runtimeStore: ConversationRuntimeStore,
        conversationVM: ConversationVM,
        conversationTurnPipelineHandler: ConversationTurnPipelineHandler,
        permissionRequestViewModel: PermissionRequestVM
    ) {
        self.runtimeStore = runtimeStore
        self.conversationVM = conversationVM
        self.conversationTurnPipelineHandler = conversationTurnPipelineHandler
        self.permissionRequestViewModel = permissionRequestViewModel
    }

    func respondToPermissionRequest(allowed: Bool) async {
        guard let conversationId = conversationVM.selectedConversationId,
              let request = runtimeStore.pendingPermissionByConversation[conversationId]
        else { return }

        runtimeStore.pendingPermissionByConversation[conversationId] = nil
        permissionRequestViewModel.setPendingPermissionRequest(nil)
        runtimeStore.updateRuntimeState(for: conversationId)

        conversationTurnPipelineHandler.emitPermissionDecision(
            allowed: allowed,
            request: request,
            conversationId: conversationId
        )
    }
}

