import Foundation
import ProviderMessage

/// 构造 Goal 自动续跑的时间线系统消息。
///
/// 这些消息只用于向用户解释后台状态，不应进入后续 LLM 上下文。
enum GoalTaskTimeline {
    static let rendererID = "core-goal-task-continuation"

    static func continuationMessage(
        conversationID: UUID,
        turnID: UUID,
        attempt: Int,
        maxAttempts: Int,
        goalTitles: [String]
    ) -> Message {
        makeMessage(
            conversationID: conversationID,
            turnID: turnID,
            action: MessageTimelineEvent.goalTaskContinuationContinuing,
            content: "Goal 自动继续（\(attempt)/\(maxAttempts)）",
            attempt: attempt,
            maxAttempts: maxAttempts,
            goalTitles: goalTitles,
            reason: "仍有未完成的 Goal 任务，正在继续执行。"
        )
    }

    static func limitReachedMessage(
        conversationID: UUID,
        turnID: UUID,
        maxAttempts: Int,
        goalTitles: [String]
    ) -> Message {
        makeMessage(
            conversationID: conversationID,
            turnID: turnID,
            action: MessageTimelineEvent.goalTaskContinuationLimitReached,
            content: "Goal 自动续跑已停止",
            attempt: nil,
            maxAttempts: maxAttempts,
            goalTitles: goalTitles,
            reason: "已达到自动续跑上限（\(maxAttempts) 次），未完成的 Goal 已标记为失败。"
        )
    }

    private static func makeMessage(
        conversationID: UUID,
        turnID: UUID,
        action: String,
        content: String,
        attempt: Int?,
        maxAttempts: Int,
        goalTitles: [String],
        reason: String
    ) -> Message {
        var metadata: [String: String] = [
            MessageTimelineEvent.metadataKey: MessageTimelineEvent.goalTaskContinuation,
            MessageTimelineEvent.goalTaskContinuationActionKey: action,
            MessageTimelineEvent.goalTaskContinuationMaxAttemptsKey: "\(maxAttempts)",
            MessageTimelineEvent.goalTaskContinuationGoalTitlesKey: goalTitles.joined(separator: "\n"),
            MessageTimelineEvent.goalTaskContinuationReasonKey: reason,
        ]
        if let attempt {
            metadata[MessageTimelineEvent.goalTaskContinuationAttemptKey] = "\(attempt)"
        }

        return Message(
            conversationID: conversationID,
            role: .system,
            content: content,
            turnID: turnID,
            metadata: metadata,
            renderKind: MessageTimelineEvent.goalTaskContinuationRenderKind,
            preferredRendererID: rendererID
        )
    }
}
