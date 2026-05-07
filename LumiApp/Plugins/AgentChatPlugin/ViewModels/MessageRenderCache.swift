import Foundation

struct MessageRenderMetadata: Equatable {
    let contentHash: Int
    let charCount: Int
    let lineCount: Int
    let containsCodeBlock: Bool
    let isLongMessage: Bool
    let shouldDefaultCollapse: Bool
}

@MainActor
final class MessageRenderCache {
    static let shared = MessageRenderCache()

    private struct Entry {
        let hash: Int
        let metadata: MessageRenderMetadata
    }

    private var metadataByMessageId: [UUID: Entry] = [:]

    func metadata(for message: ChatMessage) -> MessageRenderMetadata {
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
        return metadata
    }
}
