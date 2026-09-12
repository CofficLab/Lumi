import Foundation

/// Stable identifiers for messages that belong to the visible conversation
/// timeline but are not part of the user's conversational content.
public enum MessageTimelineEvent {
    public static let metadataKey = "lumi.timelineEvent"
    public static let contextCompaction = "context-compaction"
    public static let contextCompactionRenderKind = "context-compaction"
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
