import Foundation
import KitLLM
import ProviderAgentLoop
import ProviderMessage

// MARK: - TurnPhase

/// 回合状态机当前所处阶段。
///
/// 每个阶段携带恢复执行所需的最小上下文，保证 suspend / resume 跨 run 边界时
/// 不必回溯消息历史即可续跑。
public enum TurnPhase: Equatable {
    /// 空闲，无活跃回合。
    case idle

    /// 正在向 LLM 发起流式请求。
    case requestingLLM(turnID: UUID)

    /// 正在顺序执行一批工具调用。
    ///
    /// `pendingToolCalls` 为**尚未执行**的调用（已执行的从数组头部移除）。
    case executingTools(turnID: UUID, assistantMessageID: UUID, pendingToolCalls: [MessageToolCall])

    /// 回合挂起，等待用户响应（工具审批 / ask_user 等）。
    case awaitingUser(turnID: UUID, assistantMessageID: UUID, pendingToolCalls: [MessageToolCall], suspension: AgentLoopSuspension)

    /// 回合完成。
    case completed

    /// 回合失败。
    case failed(reason: String)

    /// 回合被取消。
    case cancelled
}

extension TurnPhase {
    /// 是否为终态。
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: return true
        default: return false
        }
    }

    /// 是否正在活跃（非 idle 且非终态）。
    public var isRunning: Bool {
        switch self {
        case .idle, .completed, .failed, .cancelled: return false
        default: return true
        }
    }

    /// 当前回合 ID。
    public var turnID: UUID? {
        switch self {
        case .idle, .completed, .cancelled: return nil
        case .requestingLLM(let id): return id
        case .executingTools(let id, _, _): return id
        case .awaitingUser(let id, _, _, _): return id
        case .failed: return nil
        }
    }
}

// MARK: - TurnRuntime

/// 单个会话的回合运行时上下文。
///
/// 收敛原先散落在 8 个字典/集合中的所有 per-conversation 状态，
/// 成为状态机的单一事实来源。
public struct TurnRuntime {
    /// 同一回合内 LLM 工具协议错误的自动恢复次数上限。
    public static let maxLLMRecoveryAttempts = 2

    /// 当前阶段。
    public var phase: TurnPhase = .idle

    /// 当前执行任务句柄（用于取消）。
    public var task: Task<Void, Never>?

    /// 当前挂起批次中所有挂起点（toolCallID → Suspension）。
    public var pendingSuspensions: [String: AgentLoopSuspension] = [:]

    /// 是否已请求取消。
    public var cancelRequested: Bool = false

    /// 当前回合已经消耗的 LLM 工具协议恢复次数。
    public var llmRecoveryAttempts: Int = 0

    /// 下一次 LLM 请求使用的一次性恢复提示，不写入会话历史。
    public var llmRecoveryHint: String?

    // MARK: - 便捷查询

    public var isRunning: Bool { phase.isRunning }
    public var isAwaitingUser: Bool {
        if case .awaitingUser = phase { return true }
        return false
    }
    public var activeSuspension: AgentLoopSuspension? {
        if case .awaitingUser(_, _, _, let s) = phase { return s }
        return nil
    }
    public var turnID: UUID? { phase.turnID }

    /// 重置为 idle。
    public mutating func reset() {
        phase = .idle
        pendingSuspensions = [:]
        cancelRequested = false
        llmRecoveryAttempts = 0
        llmRecoveryHint = nil
    }
}

// MARK: - TurnEvent

/// 输入到状态机的事件。
public enum TurnEvent {
    case startTurn(turnID: UUID)
    case cancel
    case llmResponded(response: LLMResponse, assistantMessageID: UUID)
    case llmFailed(reason: String)
    case llmRetryableFailure(reason: String)
    case toolCallCompleted(toolCallID: String, result: MessageToolResult)
    case toolNeedsUserInput(toolCallID: String, suspension: AgentLoopSuspension)
}

// MARK: - TurnReducer

/// 状态机 reducer：`(runtime, event) → (runtime, outcome?)`
///
/// - 纯函数，不执行任何 I/O
/// - 返回 `outcome` 表示回合结束（completed/failed/cancelled/suspended）
/// - 返回 `nil` 表示需要继续执行（driver 根据新 phase 决定下一步）
public enum TurnReducer {
    public static func reduce(
        _ runtime: TurnRuntime,
        event: TurnEvent
    ) -> (TurnRuntime, AgentLoopOutcome?) {
        var rt = runtime

        switch event {
        case .startTurn(let turnID):
            guard rt.phase == .idle || rt.phase.isTerminal else {
                return (rt, .failed("turn already running"))
            }
            rt.reset()
            rt.phase = .requestingLLM(turnID: turnID)
            return (rt, nil)

        case .cancel:
            rt.cancelRequested = true
            if rt.phase.isTerminal { return (rt, nil) }
            rt.pendingSuspensions = [:]
            rt.phase = .cancelled
            return (rt, .cancelled)

        case .llmResponded(let response, let assistantMessageID):
            guard case .requestingLLM(let turnID) = rt.phase else {
                return (rt, nil)
            }
            rt.llmRecoveryAttempts = 0
            rt.llmRecoveryHint = nil
            if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                let pending = toolCalls.map { tc in
                    MessageToolCall(id: tc.id, name: tc.name, arguments: tc.arguments)
                }
                rt.phase = .executingTools(
                    turnID: turnID,
                    assistantMessageID: assistantMessageID,
                    pendingToolCalls: pending
                )
                return (rt, nil)
            } else {
                rt.phase = .completed
                return (rt, .completed)
            }

        case .llmFailed(let reason):
            rt.phase = .failed(reason: reason)
            return (rt, .failed(reason))

        case .llmRetryableFailure(let reason):
            guard case .requestingLLM = rt.phase else {
                return (rt, nil)
            }
            guard rt.llmRecoveryAttempts < TurnRuntime.maxLLMRecoveryAttempts else {
                rt.phase = .failed(reason: reason)
                return (rt, .failed(reason))
            }
            rt.llmRecoveryAttempts += 1
            rt.llmRecoveryHint = "上一次工具调用没有完整到达，系统未执行任何文件操作。请重新发送完整、合法的工具调用 JSON；如果内容较大，请拆分为较小的编辑操作。不要重复解释，直接继续任务。"
            return (rt, nil)

        case .toolCallCompleted(let toolCallID, _):
            guard case .executingTools(let turnID, let assistantID, var pending) = rt.phase else {
                return (rt, nil)
            }
            pending.removeAll { $0.id == toolCallID }

            if rt.cancelRequested {
                rt.phase = .cancelled
                return (rt, .cancelled)
            }

            if pending.isEmpty {
                // 批次完成，回到 requestingLLM
                rt.phase = .requestingLLM(turnID: turnID)
            } else {
                // 还有剩余工具
                rt.phase = .executingTools(
                    turnID: turnID,
                    assistantMessageID: assistantID,
                    pendingToolCalls: pending
                )
            }
            return (rt, nil)

        case .toolNeedsUserInput(let toolCallID, let suspension):
            guard case .executingTools(let turnID, let assistantID, var pending) = rt.phase else {
                return (rt, nil)
            }
            rt.pendingSuspensions[toolCallID] = suspension
            pending.removeAll { $0.id == toolCallID }
            rt.phase = .awaitingUser(
                turnID: turnID,
                assistantMessageID: assistantID,
                pendingToolCalls: pending,
                suspension: suspension
            )
            return (rt, .suspended("awaiting user response"))
        }
    }
}
