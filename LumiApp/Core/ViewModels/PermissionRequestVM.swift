import SwiftUI
import Foundation
import MagicKit

/// 权限请求 ViewModel
/// 专门管理权限请求状态，避免因 AgentVM 其他状态变化导致不必要的视图重新渲染
@MainActor
final class PermissionRequestVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔐"
    nonisolated static let verbose = true

    /// 待处理权限请求
    @Published public fileprivate(set) var pendingPermissionRequest: PermissionRequest?

    /// 设置待处理权限请求
    func setPendingPermissionRequest(_ request: PermissionRequest?) {
        let oldValue = pendingPermissionRequest
        pendingPermissionRequest = request

        if Self.verbose {
            if let newRequest = request {
                if oldValue == nil {
                    AppLogger.core.info("\(Self.t)🔔 权限请求已设置: \(newRequest.toolName)")
                } else {
                    AppLogger.core.info("\(Self.t)🔄 权限请求已更新: \(newRequest.toolName)")
                }
            } else {
                if oldValue != nil {
                    AppLogger.core.info("\(Self.t)✅ 权限请求已清除")
                }
            }
        }
    }
}
