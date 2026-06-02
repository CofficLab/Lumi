import Foundation
import LumiCoreKit

public struct MessageRenderMetadata: Equatable {
    public let contentHash: Int
    public let charCount: Int
    public let lineCount: Int
    public let containsCodeBlock: Bool
    public let isLongMessage: Bool
    public let shouldDefaultCollapse: Bool
}

@MainActor
public final class MessageRenderCache {
    public static let shared = MessageRenderCache()

    private struct Entry {
        let hash: Int
        let metadata: MessageRenderMetadata
    }

    private let limit = 512
    private var metadataByMessageId: [UUID: Entry] = [:]
    private var messageIds: [UUID] = []

    public func metadata(for message: ChatMessage) -> MessageRenderMetadata {
        let content = message.content
        var hasher = Hasher()
        hasher.combine(content)
        let contentHash = hasher.finalize()

        if let existing = metadataByMessageId[message.id], existing.hash == contentHash {
            return existing.metadata
        }

        let charCount = content.count
        let lineCount = content.reduce(into: 1) { count, ch in
            if ch == "\n" { count += 1 }
        }
        let containsCodeBlock = content.contains("```")
        let isLongMessage = charCount > 1000 || lineCount > 50
        let shouldDefaultCollapse = isLongMessage || (containsCodeBlock && lineCount > 20)

        let metadata = MessageRenderMetadata(
            contentHash: contentHash,
            charCount: charCount,
            lineCount: lineCount,
            containsCodeBlock: containsCodeBlock,
            isLongMessage: isLongMessage,
            shouldDefaultCollapse: shouldDefaultCollapse
        )
        metadataByMessageId[message.id] = Entry(hash: contentHash, metadata: metadata)
        if !messageIds.contains(message.id) {
            messageIds.append(message.id)
        }
        evictIfNeeded()
        return metadata
    }

    private func evictIfNeeded() {
        guard messageIds.count > limit else { return }

        let overflow = messageIds.count - limit
        for messageId in messageIds.prefix(overflow) {
            metadataByMessageId.removeValue(forKey: messageId)
        }
        messageIds.removeFirst(overflow)
    }
}
