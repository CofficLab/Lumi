import SwiftUI
import Foundation

/// 权限请求 ViewModel
/// 专门管理权限请求状态，避免因 AgentProvider 其他状态变化导致不必要的视图重新渲染
@MainActor
final class PermissionRequestViewModel: ObservableObject {
    /// 待处理权限请求
    @Published public fileprivate(set) var pendingPermissionRequest: PermissionRequest?

    /// 设置待处理权限请求
    func setPendingPermissionRequest(_ request: PermissionRequest?) {
        pendingPermissionRequest = request
    }
}