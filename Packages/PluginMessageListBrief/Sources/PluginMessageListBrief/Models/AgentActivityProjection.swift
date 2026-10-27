import Foundation
import ProviderAgentLoop
import ProviderConversationState
import ProviderMessageStreaming

/// Brief 模式下独立于消息时间线的实时活动阶段。
enum AgentActivityPhase: Equatable, Sendable {
    case sending
    case thinking
    case generating
    case executingTool
    case waitingForUser

    var iconName: String {
        switch self {
        case .sending: return "arrow.up.circle"
        case .thinking: return "sparkles"
        case .generating: return "text.cursor"
        case .executingTool: return "wrench.and.screwdriver"
        case .waitingForUser: return "hand.raised"
        }
    }
}

/// 专用活动视图消费的最小 UI 状态。
///
/// 这里故意不携带 reasoning 正文和工具原始输出；Brief 只需要知道当前阶段
/// 以及必要的工具描述。
struct AgentActivityProjection: Equatable, Sendable {
    let phase: AgentActivityPhase
    let title: String
    let detail: String?

    /// 状态卡那一行的完整文本。
    ///
    /// 状态卡恒为**一行**：标题与细节合并到同一行，中间用「·」分隔；
    /// 细节缺失或为空时只显示标题。
    ///
    /// 历史上状态卡是「标题 + 细节」上下两行，细节缺失时用占位空格把第二行
    /// 藏起来，于是用户看到的状态卡时而一行时而两行。现在统一成一行，
    /// 视觉不再随阶段抖动。
    var statusLineText: String {
        guard let detail, !detail.isEmpty else { return title }
        return "\(title) · \(detail)"
    }

    static func resolve(
        conversationState: ConversationStateSnapshot?,
        streamingStage: MessageStreamingStage
    ) -> AgentActivityProjection? {
        if let activity = conversationState?.activity {
            switch activity {
            case .executingTool:
                let jobActivity = conversationState?.jobActivity
                let description = jobActivity?.recentJobDescription
                let runningCount = jobActivity?.runningJobCount ?? 0
                if runningCount > 1 {
                    return AgentActivityProjection(
                        phase: .executingTool,
                        title: "正在执行 \(runningCount) 个任务",
                        detail: description.map { "最近：\($0)" }
                    )
                }
                return AgentActivityProjection(
                    phase: .executingTool,
                    title: "正在执行",
                    detail: description
                )
            case .waitingForUser:
                return AgentActivityProjection(
                    phase: .waitingForUser,
                    title: "等待你的确认",
                    detail: conversationState?.jobActivity.recentJobDescription
                )
            case .sending, .thinking:
                break
            }
        }

        switch streamingStage {
        case .sending:
            return AgentActivityProjection(phase: .sending, title: "正在发送消息…", detail: nil)
        case .thinking:
            return AgentActivityProjection(phase: .thinking, title: "正在思考…", detail: nil)
        case .generating:
            return AgentActivityProjection(phase: .generating, title: "正在生成回复…", detail: nil)
        case .idle:
            break
        }

        switch conversationState?.activity {
        case .sending:
            return AgentActivityProjection(phase: .sending, title: "正在发送消息…", detail: nil)
        case .thinking:
            return AgentActivityProjection(phase: .thinking, title: "正在思考…", detail: nil)
        case .executingTool, .waitingForUser, .none:
            break
        }

        // activity 可能在工具完成、流式阶段切换等事件之间短暂为空，但只要
        // AgentLoop 尚未结束，底部状态行就必须继续存在。
        switch conversationState?.agentLoopState {
        case .running:
            return AgentActivityProjection(phase: .thinking, title: "正在处理…", detail: nil)
        case .suspended:
            return AgentActivityProjection(
                phase: .waitingForUser,
                title: "等待你的确认",
                detail: conversationState?.jobActivity.recentJobDescription
            )
        case .idle, .completed, .failed, .cancelled, .none:
            return nil
        }
    }
}
