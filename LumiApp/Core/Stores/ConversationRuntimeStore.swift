import Foundation
import SwiftUI

/// 会话运行态存储（按会话隔离的临时状态）
@MainActor
final class ConversationRuntimeStore: ObservableObject {
    struct StreamSessionState {
        var messageId: UUID?
    }

    @Published var streamStateByConversation: [UUID: StreamSessionState] = [:]
    @Published var streamingTextByConversation: [UUID: String] = [:]
    var thinkingTextByConversation: [UUID: String] = [:]
    var pendingStreamTextByConversation: [UUID: String] = [:]
    var pendingThinkingTextByConversation: [UUID: String] = [:]
    var lastStreamFlushAtByConversation: [UUID: Date] = [:]
    var lastThinkingFlushAtByConversation: [UUID: Date] = [:]

    var thinkingConversationIds = Set<UUID>()
    var processingConversationIds = Set<UUID>()

    var pendingPermissionByConversation: [UUID: PermissionRequest] = [:]
    var depthWarningByConversation: [UUID: DepthWarning] = [:]
    var errorMessageByConversation: [UUID: String?] = [:]
    var lastHeartbeatByConversation: [UUID: Date?] = [:]

    var streamStartedAtByConversation: [UUID: Date] = [:]
    var didReceiveFirstTokenByConversation: Set<UUID> = []

    // MARK: - MessageSend middlewares state

    /// 记录最近一次用户发送消息的时间（用于防抖/节流）。
    var lastUserSendAtByConversation: [UUID: Date] = [:]
    /// 记录最近一次用户发送消息的文本内容（用于重复发送去重）。
    var lastUserSendContentByConversation: [UUID: String] = [:]

    // MARK: - ConversationTurn middlewares state

    /// 记录已做过“后处理”的消息 ID（避免同一条 assistant 消息被重复处理）。
    var postProcessedMessageIdsByConversation: [UUID: Set<UUID>] = [:]

    /// `ConversationTurnVM`/后续 middleware 共享的轮次控制上下文（跨多深度 step 保存）。
    var turnContextsByConversation: [UUID: ConversationTurnContext] = [:]

    @Published private(set) var conversationRuntimeStates: [UUID: ConversationRuntimeState] = [:]

    /// 时间线等订阅：流式文本经 throttle 写入 store 后显式递增，避免仅靠全量 `objectWillChange` 难以精准刷新占位气泡。
    @Published private(set) var streamingPresentationVersion: Int = 0

    func bumpStreamingPresentation() {
        streamingPresentationVersion &+= 1
    }

    func runtimeState(for conversationId: UUID) -> ConversationRuntimeState {
        conversationRuntimeStates[conversationId] ?? .idle
    }

    func updateRuntimeState(for conversationId: UUID) {
        let hasError = (errorMessageByConversation[conversationId] ?? nil) != nil
        let hasPermissionRequest = pendingPermissionByConversation[conversationId] != nil
        let isGenerating = processingConversationIds.contains(conversationId) ||
            (streamStateByConversation[conversationId]?.messageId != nil)

        let state: ConversationRuntimeState
        if hasError {
            state = .error
        } else if hasPermissionRequest {
            state = .waitingPermission
        } else if isGenerating {
            state = .generating
        } else {
            state = .idle
        }

        if state == .idle {
            conversationRuntimeStates.removeValue(forKey: conversationId)
        } else {
            conversationRuntimeStates[conversationId] = state
        }
    }

    /// 供 `ConversationChangedHandler` 投影到各 UI VM 的快照。
    func agentRuntimeSnapshot(for conversationId: UUID) -> AgentRuntimeSnapshot {
        AgentRuntimeSnapshot(
            isProcessing: processingConversationIds.contains(conversationId),
            lastHeartbeatTime: lastHeartbeatByConversation[conversationId] ?? nil,
            isThinking: thinkingConversationIds.contains(conversationId),
            thinkingText: thinkingTextByConversation[conversationId] ?? "",
            pendingPermissionRequest: pendingPermissionByConversation[conversationId],
            depthWarning: depthWarningByConversation[conversationId]
        )
    }
}
