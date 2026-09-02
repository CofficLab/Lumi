import Foundation

@MainActor
public final class DefaultMessageManager: MessageManaging {
    @Published private var storage: [UUID: [Message]] = [:]
    private var insertionObservers: [UUID: (Message, UUID) -> Void] = [:]
    private var changeObservers: [UUID: (MessageChange) -> Void] = [:]

    public init() {}

    public func messages(for conversationID: UUID) -> [Message] {
        storage[conversationID, default: []].sorted { $0.createdAt < $1.createdAt }
    }

    public func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        messages(for: conversationID)
    }

    public func messagesForLLM(in conversationID: UUID) async -> [Message] {
        await messagesSnapshot(in: conversationID)
    }

    public func messagePage(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool = false
    ) -> [Message] {
        guard limit > 0 else { return [] }
        let all = messages(for: conversationID)
            .filter { includesToolMessages || $0.role != .tool }
        guard let beforeMessageID else { return Array(all.suffix(limit)) }
        guard let index = all.firstIndex(where: { $0.id == beforeMessageID }) else { return [] }
        return Array(all[max(0, index - limit)..<index])
    }

    public func hasEarlierMessages(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool = false
    ) -> Bool {
        let all = messages(for: conversationID)
            .filter { includesToolMessages || $0.role != .tool }
        guard let beforeMessageID else { return all.count > 10 }
        guard let index = all.firstIndex(where: { $0.id == beforeMessageID }) else { return false }
        return index > 0
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

    public func dailyMessageCounts(since: Date) -> [Date: Int] {
        let calendar = Calendar.current
        return storage.values
            .joined()
            .filter { $0.createdAt >= since }
            .reduce(into: [:]) { counts, message in
                counts[calendar.startOfDay(for: message.createdAt), default: 0] += 1
            }
    }

    public func dailyTokenCounts(since: Date) -> [Date: Int] {
        let calendar = Calendar.current
        return storage.values
            .joined()
            .filter { $0.createdAt >= since }
            .reduce(into: [:]) { counts, message in
                let tokens = (message.inputTokenCount ?? 0) + (message.outputTokenCount ?? 0)
                guard tokens > 0 else { return }
                counts[calendar.startOfDay(for: message.createdAt), default: 0] += tokens
            }
    }

    public func insertMessage(_ message: Message, to conversationID: UUID) {
        storage[conversationID, default: []].append(message)
        let change = MessageChange.inserted(message, conversationID: conversationID)
        changeObservers.values.forEach { $0(change) }
        insertionObservers.values.forEach { $0(message, conversationID) }
    }

    @discardableResult
    public func addMessageInsertedObserver(
        _ callback: @escaping (Message, UUID) -> Void
    ) -> any MessageInsertedObserverHandle {
        let id = UUID()
        insertionObservers[id] = callback
        return InsertionObserverHandle { [weak self] in
            self?.insertionObservers.removeValue(forKey: id)
        }
    }

    @discardableResult
    public func addMessageChangeObserver(
        _ callback: @escaping (MessageChange) -> Void
    ) -> any MessageChangeObserverHandle {
        let id = UUID()
        changeObservers[id] = callback
        return ChangeObserverHandle { [weak self] in
            self?.changeObservers.removeValue(forKey: id)
        }
    }

    public func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        guard let index = storage[conversationID]?.firstIndex(where: { $0.id == id }) else { return }
        storage[conversationID]?[index].content = content
    }

    public func deleteMessage(id: UUID, in conversationID: UUID) {
        storage[conversationID]?.removeAll { $0.id == id }
    }

    public func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String? = nil
    ) {
        guard let index = storage[conversationID]?.firstIndex(where: { $0.id == assistantMessageID }),
              let callIndex = storage[conversationID]?[index].toolCalls?.firstIndex(where: { $0.id == toolCallID })
        else { return }
        storage[conversationID]?[index].toolCalls?[callIndex].result = result
        if let authorizationState {
            storage[conversationID]?[index].toolCalls?[callIndex].authorizationState = authorizationState
        }
    }

    public func clearMessages(in conversationID: UUID) {
        storage[conversationID] = []
    }

}

@MainActor
private final class InsertionObserverHandle: MessageInsertedObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}

@MainActor
private final class ChangeObserverHandle: MessageChangeObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}
