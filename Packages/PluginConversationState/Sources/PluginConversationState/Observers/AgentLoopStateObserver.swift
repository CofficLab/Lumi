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

    /// 事件是否属于已被新回合取代的旧回合（#438）。
    ///
    /// 终态通知异步投递，旧回合的迟到终态不得把新回合的 running 状态
    /// 覆盖成 completed/failed/cancelled。快照尚未记录 turnID（观察者
    /// 中途接入、外部回合未发 started）或事件未携带 turnID 时保持旧行为。
    private func isStale(_ turn: UUID?, for conversationID: UUID) -> Bool {
        guard let turn, let current = provider.state(for: conversationID).turnID else { return false }
        return turn != current
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
            guard !isStale(turn, for: id) else { return }
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
            guard !isStale(turn, for: id) else { return }
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
            guard !isStale(turn, for: id) else { return }
            provider.update(
                conversationID: id,
                turnID: turn,
                agentLoopState: .completed,
                toolState: .completed,
                authorizationState: ConversationAuthorizationState.none,
                clearActivity: true
            )
        case .failed(let id, let turn, let reason):
            guard !isStale(turn, for: id) else { return }
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
            guard !isStale(turn, for: id) else { return }
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
