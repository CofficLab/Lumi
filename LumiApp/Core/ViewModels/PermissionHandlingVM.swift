import Foundation

/// 仅负责处理“工具执行权限请求”的批准/拒绝逻辑。
@MainActor
final class PermissionHandlingVM: ObservableObject {
    private let runtimeStore: ConversationRuntimeStore
    private let conversationVM: ConversationVM
    private let permissionRequestViewModel: PermissionRequestVM
    private let emitPermissionDecision: @MainActor (Bool, PermissionRequest, UUID) -> Void

    init(
        runtimeStore: ConversationRuntimeStore,
        conversationVM: ConversationVM,
        permissionRequestViewModel: PermissionRequestVM,
        emitPermissionDecision: @escaping @MainActor (Bool, PermissionRequest, UUID) -> Void
    ) {
        self.runtimeStore = runtimeStore
        self.conversationVM = conversationVM
        self.permissionRequestViewModel = permissionRequestViewModel
        self.emitPermissionDecision = emitPermissionDecision
    }

    func respondToPermissionRequest(allowed: Bool) async {
        guard let conversationId = conversationVM.selectedConversationId,
              let request = runtimeStore.pendingPermissionByConversation[conversationId]
        else { return }

        runtimeStore.pendingPermissionByConversation[conversationId] = nil
        permissionRequestViewModel.setPendingPermissionRequest(nil)
        runtimeStore.updateRuntimeState(for: conversationId)

        emitPermissionDecision(allowed, request, conversationId)
    }
}

