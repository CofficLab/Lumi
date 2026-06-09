import Foundation

public enum RequestLogSummaryStore {
    public struct Entry: Identifiable, Sendable {
        public let id: UUID
        public let conversationID: UUID
        public let timestamp: Date
        public let messageCount: Int
        public let systemPromptLength: Int

        public init(
            id: UUID = UUID(),
            conversationID: UUID,
            timestamp: Date = Date(),
            messageCount: Int,
            systemPromptLength: Int
        ) {
            self.id = id
            self.conversationID = conversationID
            self.timestamp = timestamp
            self.messageCount = messageCount
            self.systemPromptLength = systemPromptLength
        }
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var entries: [Entry] = []
    private static let maxEntries = 100

    public static func append(_ entry: Entry) {
        lock.lock()
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        lock.unlock()
    }

    public static func allEntries() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }
}
