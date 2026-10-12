import Foundation

/// Stable identifiers for messages that belong to the visible conversation
/// timeline but are not part of the user's conversational content.
public enum MessageTimelineEvent {
    public static let metadataKey = "lumi.timelineEvent"
    public static let contextCompaction = "context-compaction"
    public static let contextCompactionRenderKind = "context-compaction"
    public static let agentLoopRetry = "agent-loop-retry"
    public static let agentLoopRetryRenderKind = "agent-loop-retry"
    public static let agentLoopRetryAttemptKey = "agentLoopRetryAttempt"
    public static let agentLoopRetryMaxAttemptsKey = "agentLoopRetryMaxAttempts"
    public static let agentLoopRetryReasonKey = "agentLoopRetryReason"
    public static let agentLoopRetryKindKey = "agentLoopRetryKind"
    public static let agentLoopRetryProviderIDKey = "agentLoopRetryProviderID"
    public static let agentLoopRetryModelNameKey = "agentLoopRetryModelName"
    public static let agentLoopRetryHTTPStatusCodeKey = "agentLoopRetryHTTPStatusCode"
    public static let goalTaskContinuation = "goal-task-continuation"
    public static let goalTaskContinuationRenderKind = "goal-task-continuation"
    public static let goalTaskContinuationActionKey = "goalTaskContinuationAction"
    public static let goalTaskContinuationAttemptKey = "goalTaskContinuationAttempt"
    public static let goalTaskContinuationMaxAttemptsKey = "goalTaskContinuationMaxAttempts"
    public static let goalTaskContinuationGoalTitlesKey = "goalTaskContinuationGoalTitles"
    public static let goalTaskContinuationReasonKey = "goalTaskContinuationReason"
    public static let goalTaskContinuationContinuing = "continuing"
    public static let goalTaskContinuationLimitReached = "limit-reached"
    public static let actualContextCompactionKey = "contextCompactionActual"
    public static let actualContextCompactionValue = "true"
    public static let contextCompactionSchemaVersionKey = "contextCompactionSchemaVersion"
    public static let contextCompactionReasonKey = "contextCompactionReason"
    public static let contextCompactionContextWindowTokensKey = "contextCompactionContextWindowTokens"
    public static let contextCompactionEffectiveWindowTokensKey = "contextCompactionEffectiveWindowTokens"
    public static let contextCompactionInputTokenLimitKey = "contextCompactionInputTokenLimit"
    public static let contextCompactionEstimateSourceKey = "contextCompactionEstimateSource"
    public static let contextCompactionOriginalEstimateKey = "contextCompactionOriginalEstimate"
    public static let contextCompactionCompactedEstimateKey = "contextCompactionCompactedEstimate"
    public static let contextCompactionSourceLastMessageIDKey = "contextCompactionSourceLastMessageID"

    public enum ContextCompactionReason: String, Sendable, Equatable {
        case hardThreshold = "hard-threshold"
        case emergency = "emergency"
        case contextLimitRetry = "context-limit-retry"
        case legacy = "legacy"
    }

    public static func isContextCompaction(_ message: Message) -> Bool {
        message.renderKind == contextCompactionRenderKind
            || message.metadata[metadataKey] == contextCompaction
    }

    public static func isAgentLoopRetry(_ message: Message) -> Bool {
        message.renderKind == agentLoopRetryRenderKind
            || message.metadata[metadataKey] == agentLoopRetry
    }

    public static func isGoalTaskContinuation(_ message: Message) -> Bool {
        message.renderKind == goalTaskContinuationRenderKind
            || message.metadata[metadataKey] == goalTaskContinuation
    }

    /// 仅用于界面时间线的消息不应被重新发送给 LLM。
    public static func isTimelineEvent(_ message: Message) -> Bool {
        isContextCompaction(message) || isAgentLoopRetry(message) || isGoalTaskContinuation(message)
    }

    /// 只有真正用于压缩上下文的事件才应显示在消息列表中。
    /// 旧版本把后台摘要预热也记录成了压缩事件，因此没有该标记的历史事件继续隐藏。
    public static func isActualContextCompaction(_ message: Message) -> Bool {
        isContextCompaction(message)
            && message.metadata[actualContextCompactionKey] == actualContextCompactionValue
    }

    public static func compactionReason(for message: Message) -> ContextCompactionReason {
        guard let rawValue = message.metadata[contextCompactionReasonKey],
              let reason = ContextCompactionReason(rawValue: rawValue) else {
            return .legacy
        }
        return reason
    }

    public static func integerMetadata(_ key: String, from message: Message) -> Int? {
        guard let value = message.metadata[key] else { return nil }
        return Int(value)
    }
}
