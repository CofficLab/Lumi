import Foundation

/// Stable identifiers for messages that belong to the visible conversation
/// timeline but are not part of the user's conversational content.
public enum MessageTimelineEvent {
    public static let metadataKey = "lumi.timelineEvent"
    public static let contextCompaction = "context-compaction"
    public static let contextCompactionRenderKind = "context-compaction"
    public static let actualContextCompactionKey = "contextCompactionActual"
    public static let actualContextCompactionValue = "true"

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
}
