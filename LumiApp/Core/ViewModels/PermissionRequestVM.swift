import SwiftUI
import Foundation
import MagicKit

/// 与 `pendingPermissionRequest` 配套的会话上下文（用于落库与恢复发送）
struct PendingToolPermissionSession: Equatable, Sendable {
    let conversationId: UUID
    let assistantMessageId: UUID
}

/// 权限请求 ViewModel
@MainActor
final class PermissionRequestVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔐"
    nonisolated static let verbose: Bool = true
    /// 待处理权限请求
    @Published public fileprivate(set) var pendingPermissionRequest: PermissionRequest?

    /// 当前权限浮层对应的助手消息与会话（用于写回 `ToolCall.authorizationState`）
    @Published public fileprivate(set) var pendingToolPermissionSession: PendingToolPermissionSession?

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

    func setPendingToolPermissionSession(_ session: PendingToolPermissionSession?) {
        pendingToolPermissionSession = session
    }
}
