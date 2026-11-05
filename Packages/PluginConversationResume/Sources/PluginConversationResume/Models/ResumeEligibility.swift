import Foundation
import ProviderAgentLoop
import ProviderMessage

/// 判定某个会话是否处于「异常中断、可继续」状态。
///
/// ## 判定输入
///
/// 判定需要三类事实：
///
/// 1. **持久化的回合终态**（`ResumableTurnStore`）—— 唯一能区分
///    「用户主动停止」与「进程消失」的来源；
/// 2. **消息历史** —— 用来确认回合确实没跑完，以及定位孤儿 tool_call；
/// 3. **当前 AgentLoop 状态** —— 排除「其实还活着」的误判。
///
/// ## 为什么消息不够
///
/// 见 `ResumableTurnRecord` 的文档：崩溃与用户停止留下的消息形状一致。
/// 消息只能回答「回合有没有跑完」，回答不了「是不是出问题了」。
enum ResumeEligibility {
    /// 判定结论。
    enum Verdict: Equatable, Sendable {
        /// 可以继续。
        case resumable(reason: String)
        /// 不该显示继续提示。
        case notResumable(reason: String)
    }

    /// 判定所需的输入。
    struct Input: Sendable {
        /// 持久化的回合记录。没有记录说明这个会话没有「跑到一半」的回合。
        var turnRecord: ResumableTurnRecord?
        /// 当前 AgentLoop 状态。
        var agentLoopState: AgentLoopStateSnapshot
        /// 会话内的消息历史（按时间升序）。
        var messages: [Message]

        init(
            turnRecord: ResumableTurnRecord?,
            agentLoopState: AgentLoopStateSnapshot,
            messages: [Message]
        ) {
            self.turnRecord = turnRecord
            self.agentLoopState = agentLoopState
            self.messages = messages
        }
    }

    /// AgentLoop 状态的最小快照。
    ///
    /// 刻意不直接依赖 `AgentLoopState` 枚举：这个判定器只需要「还在跑吗」
    /// 和「在等用户吗」两个事实，收窄后便于测试与复用。
    enum AgentLoopStateSnapshot: Equatable, Sendable {
        /// 没有活跃回合。
        case idle
        /// 回合运行中。
        case running
        /// 回合挂起（等授权 / 等用户回答）—— 回合还活着，不该提示继续。
        case suspended
        /// 回合已结束（完成 / 失败 / 取消）。
        case finished

        /// 由 `ProviderAgentLoop.AgentLoopState` 映射而来。
        init(_ state: AgentLoopState) {
            switch state {
            case .idle: self = .idle
            case .running: self = .running
            case .suspended: self = .suspended
            case .completed, .failed, .cancelled: self = .finished
            }
        }
    }

    /// 执行判定。
    static func evaluate(_ input: Input) -> Verdict {
        // 1. 必须有持久化记录，且记录明确是「进程消失」。
        guard let record = input.turnRecord else {
            return .notResumable(reason: "没有未收尾的回合记录")
        }
        guard record.isResumable else {
            return .notResumable(reason: "回合已正常收尾（\(record.outcome.rawValue)）")
        }

        // 2. 回合必须真的还在跑或刚死，不能已经正常结束。
        switch input.agentLoopState {
        case .running:
            return .notResumable(reason: "回合仍在运行")
        case .suspended:
            return .notResumable(reason: "回合处于挂起状态，仍可继续交互")
        case .idle, .finished:
            break
        }

        // 3. 消息侧确认：回合确实没跑完。
        //
        // 「跑完」的定义与 `AgentTurnSummaryBuilder.isFinalAssistant` 保持一致：
        // 一条不带工具调用的 assistant 消息 = 最终回复 = 回合跑完了。
        // 如果最后一条有效消息已经是最终回复，说明这个回合其实干完了
        // （只是终态记录没写成功），不该再提示继续。
        if hasFinalAssistantReply(input.messages) {
            return .notResumable(reason: "回合已产出最终回复")
        }

        // 4. 没有任何用户消息的会话无从「继续」。
        guard input.messages.contains(where: { $0.role == .user }) else {
            return .notResumable(reason: "会话中没有用户消息")
        }

        return .resumable(reason: "上一轮在执行中被中断")
    }

    /// 历史中是否存在「最终回复」（不带工具调用的 assistant 消息）。
    ///
    /// 与 `PluginMessageListBrief.AgentTurnSummaryBuilder.isFinalAssistant`
    /// 的口径一致：不带工具调用、非错误、且正文非空的 assistant 消息。
    static func hasFinalAssistantReply(_ messages: [Message]) -> Bool {
        messages.contains { message in
            guard message.role == .assistant,
                  !message.isError,
                  (message.toolCalls?.isEmpty ?? true) else {
                return false
            }
            return !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
