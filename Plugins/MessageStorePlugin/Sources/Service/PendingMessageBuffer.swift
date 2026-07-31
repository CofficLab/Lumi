import Foundation
import LumiKernel

final class PendingMessageBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: [LumiChatMessage]] = [:]

    /// 取某会话的待落盘消息快照(按时间升序)。
    func snapshot(for conversationID: UUID) -> [LumiChatMessage] {
        lock.lock(); defer { lock.unlock() }
        return storage[conversationID] ?? []
    }

    /// 加入一条(去重:同 id 已在则替换,保持时间升序)。
    func enqueue(_ message: LumiChatMessage, conversationID: UUID) {
        lock.lock(); defer { lock.unlock() }
        var list = storage[conversationID] ?? []
        if let i = list.firstIndex(where: { $0.id == message.id }) {
            list[i] = message
        } else {
            list.append(message)
            list.sort { lhs, rhs in
                if lhs.createdAt == rhs.createdAt { return lhs.id < rhs.id }
                return lhs.createdAt < rhs.createdAt
            }
        }
        storage[conversationID] = list
    }

    /// 移除一条(后台落盘成功后调用)。
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
}
