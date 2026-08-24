import Foundation
import ProviderMessage

/// 内存中的「已通知 UI、尚未落盘」消息缓冲（write-behind 的脏数据）。
///
/// 读路径（nonisolated，可在后台线程）与写路径（@MainActor）都会访问它，故内部
/// 用锁保护并暴露为 Sendable。key=conversationID，value=该会话待落盘消息（按时间
/// 升序）。一条消息后台落盘成功后从这里移除；UI 早已显示它，移除是隐形的，无需
/// 再通知。
/// 复刻自旧版 `PendingMessageBuffer`，类型换成新版 `Message`。
final class PendingMessageBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: [Message]] = [:]

    /// 取某会话的待落盘消息快照（按时间升序）。
    func snapshot(for conversationID: UUID) -> [Message] {
        lock.lock(); defer { lock.unlock() }
        return storage[conversationID] ?? []
    }

    /// 取全部会话的待落盘消息，用于跨会话统计等全局读路径。
    func snapshotAll() -> [Message] {
        lock.lock(); defer { lock.unlock() }
        return storage.values.flatMap { $0 }
    }

    /// 加入一条（去重：同 id 已在则替换，保持时间升序）。
    func enqueue(_ message: Message, conversationID: UUID) {
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

    /// 移除一条（后台落盘成功后调用）。
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

    /// Mutate a pending message in place and return the updated value.
    @discardableResult
    func update(
        id: UUID,
        conversationID: UUID,
        _ transform: (inout Message) -> Void
    ) -> Message? {
        lock.lock(); defer { lock.unlock() }
        guard var list = storage[conversationID],
              let index = list.firstIndex(where: { $0.id == id })
        else { return nil }

        transform(&list[index])
        storage[conversationID] = list
        return list[index]
    }
}

/// 瞬时 status 消息缓冲（每会话最多一条，永不落盘）。
///
/// `role == .status` 的消息（如"正在发送…"）是视图层瞬时态。每会话只保留最新一条：
/// `set` 直接覆盖旧的；AgentTurn 生命周期结束时由拥有者显式 `clear`。
/// 锁保护、Sendable，供 MessageManager 的 nonisolated 读路径与 @MainActor 写路径共用。
final class StatusMessageBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: Message] = [:]

    /// 取某会话当前 status 快照；无则 nil。
    func snapshot(for conversationID: UUID) -> Message? {
        lock.lock(); defer { lock.unlock() }
        return storage[conversationID]
    }

    /// 设置某会话的 status（覆盖旧值）。每会话最多一条。
    func set(_ message: Message, conversationID: UUID) {
        lock.lock(); defer { lock.unlock() }
        storage[conversationID] = message
    }

    /// 清除某会话的 status。返回是否确实清掉了一条（供调用方决定是否通知）。
    @discardableResult
    func clear(conversationID: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return storage.removeValue(forKey: conversationID) != nil
    }
}
