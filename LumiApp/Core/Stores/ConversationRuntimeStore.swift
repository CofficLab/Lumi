import Foundation
import SwiftUI

/// 会话运行态存储（按会话隔离的临时状态）
///
/// ## 设计原则
///
/// - 仅存放**不落库**的运行时状态（流式占位、thinking、processing、权限请求、错误、心跳等）。
/// - 所有状态均以 `conversationId` 为 key 做会话隔离，支持多会话并发与快速切换。
/// - 由上层协调者（如 `AgentProvider` 或 Coordinator）负责把这些状态投影到各个 UI ViewModel。
///
/// ## 职责边界
///
/// - `ConversationRuntimeStore`: 维护/计算会话运行态（例如 `ConversationRuntimeState`），提供清理方法避免泄漏。
/// - `ChatHistoryService`: 负责持久化消息与会话。
/// - 具体 UI：通过 ViewModel 读取并展示状态，不直接修改 store 内部结构。
@MainActor
final class ConversationRuntimeStore: ObservableObject {
    struct StreamSessionState {
        var messageId: UUID?
        var messageIndex: Int?
    }

    @Published var streamStateByConversation: [UUID: StreamSessionState] = [:]
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
    var statusMessageIdByConversation: [UUID: UUID] = [:]

    @Published private(set) var conversationRuntimeStates: [UUID: ConversationRuntimeState] = [:]

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

    func cleanupConversationState(_ conversationId: UUID) {
        streamStateByConversation[conversationId] = StreamSessionState(messageId: nil, messageIndex: nil)
        streamStateByConversation.removeValue(forKey: conversationId)

        thinkingTextByConversation.removeValue(forKey: conversationId)
        pendingStreamTextByConversation.removeValue(forKey: conversationId)
        pendingThinkingTextByConversation.removeValue(forKey: conversationId)
        lastStreamFlushAtByConversation.removeValue(forKey: conversationId)
        lastThinkingFlushAtByConversation.removeValue(forKey: conversationId)

        thinkingConversationIds.remove(conversationId)
        processingConversationIds.remove(conversationId)

        pendingPermissionByConversation.removeValue(forKey: conversationId)
        depthWarningByConversation.removeValue(forKey: conversationId)
        errorMessageByConversation.removeValue(forKey: conversationId)
        lastHeartbeatByConversation.removeValue(forKey: conversationId)

        streamStartedAtByConversation.removeValue(forKey: conversationId)
        didReceiveFirstTokenByConversation.remove(conversationId)

        statusMessageIdByConversation.removeValue(forKey: conversationId)
        conversationRuntimeStates.removeValue(forKey: conversationId)
    }
}

