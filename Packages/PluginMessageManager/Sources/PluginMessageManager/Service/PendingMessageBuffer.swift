import Foundation
import ProviderMessage

/// 内存中的「已通知 UI、尚未落盘」消息缓冲（write-behind 的脏数据）。
final class PendingMessageBuffer: @unchecked Sendable {
    /// 一次工具结果写回的补丁。
    ///
    /// 助手消息已离开 pending（落盘完成）时，工具结果不能再在主线程 fetch + 编码 + save；
    /// 补丁先记在这里让读路径立即可见，后台落盘成功后再撤掉（issue #1229）。
    struct ToolResultPatch: Sendable {
        let result: MessageToolResult
        let authorizationState: String?
    }

    private let lock = NSLock()
    private var storage: [UUID: [Message]] = [:]

    /// conversationID → messageID → toolCallID → 补丁。
    private var toolResultStorage: [UUID: [UUID: [String: ToolResultPatch]]] = [:]

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
        toolResultStorage.removeValue(forKey: conversationID)
    }

    // MARK: - Tool Result Patches

    func enqueueToolResult(
        _ patch: ToolResultPatch,
        messageID: UUID,
        toolCallID: String,
        conversationID: UUID
    ) {
        lock.lock(); defer { lock.unlock() }
        var messages = toolResultStorage[conversationID] ?? [:]
        var patches = messages[messageID] ?? [:]
        patches[toolCallID] = patch
        messages[messageID] = patches
        toolResultStorage[conversationID] = messages
    }

    func dequeueToolResult(messageID: UUID, toolCallID: String, conversationID: UUID) {
        lock.lock(); defer { lock.unlock() }
        guard var messages = toolResultStorage[conversationID],
              var patches = messages[messageID] else { return }
        patches.removeValue(forKey: toolCallID)
        if patches.isEmpty {
            messages.removeValue(forKey: messageID)
        } else {
            messages[messageID] = patches
        }
        if messages.isEmpty {
            toolResultStorage.removeValue(forKey: conversationID)
        } else {
            toolResultStorage[conversationID] = messages
        }
    }

    func dequeueToolResults(messageID: UUID, conversationID: UUID) {
        lock.lock(); defer { lock.unlock() }
        guard var messages = toolResultStorage[conversationID] else { return }
        messages.removeValue(forKey: messageID)
        if messages.isEmpty {
            toolResultStorage.removeValue(forKey: conversationID)
        } else {
            toolResultStorage[conversationID] = messages
        }
    }

    func toolResultPatches(for conversationID: UUID) -> [UUID: [String: ToolResultPatch]] {
        lock.lock(); defer { lock.unlock() }
        return toolResultStorage[conversationID] ?? [:]
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
