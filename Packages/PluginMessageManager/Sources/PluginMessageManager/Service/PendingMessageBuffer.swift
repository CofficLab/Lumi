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
    /// conversationID → messageID → 代次（generation）。
    ///
    /// 每次 `enqueue` / `update` 递增；落盘闭包捕获自己写入的那一代，
    /// `dequeue(id:conversationID:generation:)` 只在代次匹配时移除。
    /// 否则旧的 insert/update 落盘后会按 id 撤掉**已被更新的新版本**，
    /// 让后续更新走同步磁盘分支并与队列里的旧写回竞态，旧内容覆盖新内容（#150）。
    private var generations: [UUID: [UUID: Int]] = [:]

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

    /// 加入/替换一条待落盘消息，返回本次分配的代次（供落盘闭包做版本门控 dequeue）。
    @discardableResult
    func enqueue(_ message: Message, conversationID: UUID) -> Int {
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
        let generation = (generations[conversationID]?[message.id] ?? 0) + 1
        generations[conversationID, default: [:]][message.id] = generation
        return generation
    }

    /// 版本门控移除：仅当 pending 当前代次 == 落盘闭包实际写入的代次时才移除。
    /// 代次落后（期间消息已被更新到新版本）时不动 pending，把移除留给写入新代次的那次落盘（#150）。
    func dequeue(id: UUID, conversationID: UUID, generation: Int) {
        lock.lock(); defer { lock.unlock() }
        guard generations[conversationID]?[id] == generation else { return }
        removeLocked(id: id, conversationID: conversationID)
    }

    /// 强制移除（用户删除消息）：不看代次，连同代次记录一起清掉。
    func dequeue(id: UUID, conversationID: UUID) {
        lock.lock(); defer { lock.unlock() }
        removeLocked(id: id, conversationID: conversationID)
    }

    private func removeLocked(id: UUID, conversationID: UUID) {
        generations[conversationID]?.removeValue(forKey: id)
        if generations[conversationID]?.isEmpty == true {
            generations.removeValue(forKey: conversationID)
        }
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
        generations.removeValue(forKey: conversationID)
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

    /// 原子读-改-写一条待落盘消息，递增并返回本次代次。
    /// 调用方必须为返回的代次排一个落盘写回（写入成功后做版本门控 dequeue），
    /// 否则该代次无人移除、消息滞留 pending（#150）。
    @discardableResult
    func update(id: UUID, conversationID: UUID, _ transform: (inout Message) -> Void) -> (message: Message, generation: Int)? {
        lock.lock(); defer { lock.unlock() }
        guard var list = storage[conversationID],
              let index = list.firstIndex(where: { $0.id == id }) else { return nil }
        transform(&list[index])
        storage[conversationID] = list
        let generation = (generations[conversationID]?[id] ?? 0) + 1
        generations[conversationID, default: [:]][id] = generation
        return (list[index], generation)
    }
}
