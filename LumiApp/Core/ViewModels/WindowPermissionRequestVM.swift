import SwiftUI
import Foundation
import MagicKit

/// 与 `pendingPermissionRequest` 配套的会话上下文（用于落库与恢复发送）
struct PendingToolPermissionSession: Equatable, Sendable {
    let conversationId: UUID
    let assistantMessageId: UUID
}

///
/// ## 初始化规则
///
/// 由 `WindowScope` 持有，通过 `.environmentObject()` 注入。n管理工具执行权限请求弹窗。
/// 权限请求 ViewModel
///
/// ## 初始化规则
///
/// 由 `WindowScope` 持有并通过 `.environmentObject()` 注入。
/// 管理工具执行权限请求弹窗。
@MainActor
final class WindowPermissionRequestVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔐"
    nonisolated static let verbose: Bool = false
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
