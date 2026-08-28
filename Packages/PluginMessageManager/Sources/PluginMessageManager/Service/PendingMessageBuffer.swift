import Foundation
import ProviderMessage

/// 内存中的「已通知 UI、尚未落盘」消息缓冲（write-behind 的脏数据）。
final class PendingMessageBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: [Message]] = [:]

    func snapshot(for conversationID: UUID) -> [Message] {
        lock.lock(); defer { lock.unlock() }
        return storage[conversationID] ?? []
    }

    func snapshotAll() -> [Message] {
        lock.lock(); defer { lock.unlock() }
        return storage.values.flatMap { $0 }
    }

    func enqueue(_ message: Message, conversationID: UUID) {
        lock.lock(); defer { lock.unlock() }
        var list = storage[conversationID] ?? []
        if let i = list.firstIndex(where: { $0.id == message.id }) {
            list[i] = message
        } else {
            list.append(message)
            list.sort {
                if $0.createdAt == $1.createdAt { return $0.id < $1.id }
                return $0.createdAt < $1.createdAt
            }
        }
        storage[conversationID] = list
    }

    func dequeue(id: UUID, conversationID: UUID) {
        lock.lock(); defer { lock.unlock() }
        guard var list = storage[conversationID] else { return }
        list.removeAll { $0.id == id }
        if list.isEmpty {
            storage.removeValue(forKey: conversationID)
        } else {
            storage[conversationID] = list
        }
    }

    func clear(conversationID: UUID) {
        lock.lock(); defer { lock.unlock() }
        storage.removeValue(forKey: conversationID)
    }

    @discardableResult
    func update(id: UUID, conversationID: UUID, _ transform: (inout Message) -> Void) -> Message? {
        lock.lock(); defer { lock.unlock() }
        guard var list = storage[conversationID],
              let index = list.firstIndex(where: { $0.id == id }) else { return nil }
        transform(&list[index])
        storage[conversationID] = list
        return list[index]
    }
}
