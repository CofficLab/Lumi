import Foundation

/// 仅负责处理“工具执行权限请求”的批准/拒绝逻辑。
@MainActor
final class PermissionHandlingVM: ObservableObject {
    private let runtimeStore: ConversationRuntimeStore
    private let conversationVM: ConversationVM
    private let permissionRequestViewModel: PermissionRequestVM

    init(
        runtimeStore: ConversationRuntimeStore,
        conversationVM: ConversationVM,
        permissionRequestViewModel: PermissionRequestVM
    ) {
        self.runtimeStore = runtimeStore
        self.conversationVM = conversationVM
        self.permissionRequestViewModel = permissionRequestViewModel
    }

    func respondToPermissionRequest(allowed: Bool) async {
        guard let conversationId = conversationVM.selectedConversationId,
              runtimeStore.pendingPermissionByConversation[conversationId] != nil
        else { return }

        runtimeStore.pendingPermissionByConversation[conversationId] = nil
        permissionRequestViewModel.setPendingPermissionRequest(nil)
        runtimeStore.updateRuntimeState(for: conversationId)
        let _ = allowed
    }
}
