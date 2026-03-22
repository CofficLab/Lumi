import Foundation

/// 关闭工具权限请求浮层（无持久运行态存储时的最小实现）。
@MainActor
final class PermissionHandlingVM: ObservableObject {
    private let permissionRequestViewModel: PermissionRequestVM

    init(permissionRequestViewModel: PermissionRequestVM) {
        self.permissionRequestViewModel = permissionRequestViewModel
    }

    func respondToPermissionRequest(allowed: Bool) async {
        guard permissionRequestViewModel.pendingPermissionRequest != nil else { return }
        permissionRequestViewModel.setPendingPermissionRequest(nil)
        let _ = allowed
    }
}
