import Foundation

/// 从消息历史推导 Agent 下一步动作（纯函数，无状态）。
public enum AgentTurnDerivation {

    /// 跳过 system / status 后的最后一条可驱动消息。
    public static func lastDrivableMessage(in messages: [ChatMessage]) -> ChatMessage? {
        messages.last(where: { $0.role != .system && $0.role != .status })
    }

    /// 是否应向 LLM 发起请求。
    ///
    /// - user / tool：需要 LLM
    /// - assistant 且所有 toolCalls 均有 result：需要 LLM
    public static func shouldRequestLLM(messages: [ChatMessage]) -> Bool {
        guard let last = lastDrivableMessage(in: messages) else { return false }

        switch last.role {
        case .user, .tool:
            return true
        case .assistant:
            guard last.hasToolCalls else { return false }
            return last.toolCalls?.contains(where: { $0.result == nil }) != true
        case .system, .status, .error, .unknown:
            return false
        }
    }

    /// 是否应执行工具。
    public static func shouldExecuteTools(messages: [ChatMessage], phase: AgentTurnPhase) -> Bool {
        guard phase == .processing else { return false }
        guard let last = lastDrivableMessage(in: messages), last.role == .assistant else { return false }
        guard last.hasToolCalls else { return false }
        return last.toolCalls?.contains(where: { $0.result == nil }) == true
    }

    /// Turn 是否正常完成（assistant 无 toolCalls）。
    public static func isTurnComplete(messages: [ChatMessage]) -> Bool {
        guard let last = lastDrivableMessage(in: messages) else { return false }
        return last.role == .assistant && !last.hasToolCalls
    }

    /// 是否存在待发送的 user 消息。
    public static func hasPendingUserMessage(in messages: [ChatMessage]) -> Bool {
        messages.contains { $0.role == .user && $0.queueStatus == .pending }
    }

    /// 是否应启动队列中的下一条 Turn（phase 空闲且存在 pending user 消息）。
    public static func shouldStartQueuedTurn(messages: [ChatMessage], phase: AgentTurnPhase) -> Bool {
        guard phase == .idle else { return false }
        return hasPendingUserMessage(in: messages)
    }

    /// 是否应在 Turn 结束后尝试出队下一条（与 shouldStartQueuedTurn 等价，语义用于 idle 事件）。
    public static func shouldDequeueNextTurn(messages: [ChatMessage], phase: AgentTurnPhase) -> Bool {
        shouldStartQueuedTurn(messages: messages, phase: phase)
    }

    /// 最早的一条 pending user 消息。
    public static func firstPendingUserMessage(in messages: [ChatMessage]) -> ChatMessage? {
        messages
            .filter { $0.role == .user && $0.queueStatus == .pending }
            .min(by: { $0.timestamp < $1.timestamp })
    }
}
