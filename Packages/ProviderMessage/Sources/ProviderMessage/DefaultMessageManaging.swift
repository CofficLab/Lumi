import Foundation

@MainActor
public final class DefaultMessageManaging: MessageManaging {
    @Published private var storage: [UUID: [Message]] = [:]

    public init() {}

    public func messages(for conversationID: UUID) -> [Message] {
        storage[conversationID, default: []].sorted { $0.createdAt < $1.createdAt }
    }

    public func message(id: UUID, in conversationID: UUID) -> Message? {
        storage[conversationID]?.first { $0.id == id }
    }

    public func lastMessage(in conversationID: UUID) -> Message? {
        messages(for: conversationID).last
    }

    public func messageCount(for conversationID: UUID) -> Int {
        storage[conversationID]?.count ?? 0
    }

    public func insertMessage(_ message: Message, to conversationID: UUID) {
        storage[conversationID, default: []].append(message)
    }

    public func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        guard let index = storage[conversationID]?.firstIndex(where: { $0.id == id }) else { return }
        storage[conversationID]?[index].content = content
    }

    public func deleteMessage(id: UUID, in conversationID: UUID) {
        storage[conversationID]?.removeAll { $0.id == id }
    }

    public func clearMessages(in conversationID: UUID) {
        storage[conversationID] = []
    }

    public func clearStatusMessages(in conversationID: UUID) {
        guard var rows = storage[conversationID] else { return }
        let filtered = rows.filter { $0.metadata["isTransientStatus"] != "true" }
        guard filtered.count != rows.count else { return }
        rows = filtered
        storage[conversationID] = rows
    }
}
