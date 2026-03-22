import Foundation
import SwiftUI

/// 会话运行态存储（按会话隔离的临时状态，供侧栏徽标等使用）
@MainActor
final class ConversationRuntimeStore: ObservableObject {
    var pendingPermissionByConversation: [UUID: PermissionRequest] = [:]
    var errorMessageByConversation: [UUID: String?] = [:]

    @Published private(set) var conversationRuntimeStates: [UUID: ConversationRuntimeState] = [:]

    func runtimeState(for conversationId: UUID) -> ConversationRuntimeState {
        conversationRuntimeStates[conversationId] ?? .idle
    }

    func updateRuntimeState(for conversationId: UUID) {
        let hasError = (errorMessageByConversation[conversationId] ?? nil) != nil
        let hasPermissionRequest = pendingPermissionByConversation[conversationId] != nil

        let state: ConversationRuntimeState
        if hasError {
            state = .error
        } else if hasPermissionRequest {
            state = .waitingPermission
        } else {
            state = .idle
        }

        if state == .idle {
            conversationRuntimeStates.removeValue(forKey: conversationId)
        } else {
            conversationRuntimeStates[conversationId] = state
        }
    }

    /// 供 `RootView+ConversationLifecycle` 投影到各 UI VM 的快照。
    func agentRuntimeSnapshot(for conversationId: UUID) -> AgentRuntimeSnapshot {
        AgentRuntimeSnapshot(
            pendingPermissionRequest: pendingPermissionByConversation[conversationId]
        )
    }
}
