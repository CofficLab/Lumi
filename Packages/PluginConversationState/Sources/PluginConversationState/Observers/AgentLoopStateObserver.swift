import Foundation
import LumiLoggingKit
import os
import ProviderAgentLoop
import ProviderConversationState

/// 将 AgentLoop 生命周期事件转换为会话状态更新。
@MainActor
final class AgentLoopStateObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-state",
        category: "AgentLoopStateObserver"
    )

    private let provider: ConversationStateProvider
    private weak var agentLoop: (any AgentLoopProviding)?
    private var handle: (any AgentLoopObserverHandle)?

    init(agentLoop: any AgentLoopProviding, provider: ConversationStateProvider) {
        self.provider = provider
        self.agentLoop = agentLoop
        handle = agentLoop.addAgentLoopObserver { [weak self] event in
            self?.consume(event)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }

    private func consume(_ event: AgentLoopEvent) {
        switch event {
        case .started(let id, let turn):
            provider.update(
                conversationID: id,
                turnID: turn,
                agentLoopState: .running,
                toolState: .idle,
                authorizationState: ConversationAuthorizationState.none,
                activity: .thinking,
                clearError: true
            )
        case .toolCallsReceived(let id, let turn, _, _):
            // 回合恢复后会重新进入这一步：用户已经做出授权/回答决定，
            // 会话级授权状态必须回落，否则盾牌会一直挂到回合结束。
            provider.update(
                conversationID: id,
                turnID: turn,
                agentLoopState: .running,
                toolState: .executing,
                authorizationState: ConversationAuthorizationState.none,
                activity: .executingTool
            )
        case .llmResponseReceived(let id, let turn, _):
            provider.update(
                conversationID: id,
                turnID: turn,
                agentLoopState: .running,
                authorizationState: ConversationAuthorizationState.none,
                activity: .thinking
            )
        case .suspended(let id, let turn, let suspension):
            guard let agentLoop,
                  agentLoop.state(for: id) == .suspended,
                  agentLoop.currentTurnID(for: id) == turn,
                  agentLoop.suspension(for: id)?.suspensionID == suspension.suspensionID else {
                return
            }
            provider.update(
                conversationID: id,
                turnID: turn,
                agentLoopState: .suspended,
                toolState: .suspended,
                // 执行期授权（如 Computer Use 的应用授权）不经过
                // `ToolManagerEvent.authorizationRequired`，只能在这里依据
                // 挂起载荷标记 `.required`。`ask_user` 等交互挂起载荷没有
                // `kind` 字段，不能误标成授权等待。
                authorizationState: suspension.isAuthorizationSuspension
                    ? ConversationAuthorizationState.required
                    : nil,
                activity: .waitingForUser
            )
        case .completed(let id, let turn):
            provider.update(
                conversationID: id,
                turnID: turn,
                agentLoopState: .completed,
                toolState: .completed,
                authorizationState: ConversationAuthorizationState.none,
                clearActivity: true
            )
        case .failed(let id, let turn, let reason):
            Self.logger.error("\(Self.t)AgentLoop failed conversation=\(id.uuidString, privacy: .public): \(reason, privacy: .public)")
            provider.update(
                conversationID: id,
                turnID: turn,
                agentLoopState: .failed,
                toolState: .completed,
                authorizationState: ConversationAuthorizationState.none,
                clearActivity: true,
                lastError: reason
            )
        case .cancelled(let id, let turn):
            provider.update(
                conversationID: id,
                turnID: turn,
                agentLoopState: .cancelled,
                toolState: .completed,
                authorizationState: ConversationAuthorizationState.none,
                clearActivity: true
            )
        }
    }
}
