import Foundation

/// Stable identifiers for messages that belong to the visible conversation
/// timeline but are not part of the user's conversational content.
public enum MessageTimelineEvent {
    public static let metadataKey = "lumi.timelineEvent"
    public static let contextCompaction = "context-compaction"
    public static let contextCompactionRenderKind = "context-compaction"

    public static func isContextCompaction(_ message: Message) -> Bool {
        message.renderKind == contextCompactionRenderKind
            || message.metadata[metadataKey] == contextCompaction
    }
}
