import Foundation
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
            return nil
        }
    }
}
