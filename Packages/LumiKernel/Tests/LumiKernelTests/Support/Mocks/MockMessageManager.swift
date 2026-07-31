import Combine
import Foundation
@testable import LumiKernel

/// 测试用 `MessageManaging` 实现。
///
/// 读方法用锁保护(协议读路径是非隔离的,可在后台线程调用);写方法标
/// `@MainActor` 与协议一致。可选注入 `OrchestrationEventLog` 记录写入顺序,
/// 用于断言编排规则。
final class MockMessageManager: MessageManaging, @unchecked Sendable {
    let objectWillChange = ObservableObjectPublisher()
    let log: OrchestrationEventLog?

    private let lock = NSLock()
    private var storage: [UUID: [LumiChatMessage]] = [:]

    init(log: OrchestrationEventLog? = nil) {
        self.log = log
    }

    // MARK: 观测辅助(测试断言用)

    func insertedMessages(in conversationID: UUID) -> [LumiChatMessage] {
        lock.lock(); defer { lock.unlock() }
        return storage[conversationID] ?? []
    }

    /// 直接预置消息(不走 log,用于夹具准备历史)。
    func seed(_ message: LumiChatMessage, in conversationID: UUID) {
        lock.lock(); defer { lock.unlock() }
        storage[conversationID, default: []].append(message)
    }

    // MARK: MessageManaging(读,非隔离)

    func messages(for conversationID: UUID) -> [LumiChatMessage] {
        lock.lock(); defer { lock.unlock() }
        return storage[conversationID] ?? []
    }

    func messagePage(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) -> [LumiChatMessage] {
        Array(messages(for: conversationID).suffix(limit))
    }

    func messageCount(for conversationID: UUID) -> Int {
        messages(for: conversationID).count
    }

    func hasEarlierMessages(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) -> Bool { false }

    func message(id: UUID, in conversationID: UUID) -> LumiChatMessage? {
        messages(for: conversationID).first { $0.id == id }
    }

    func lastMessage(in conversationID: UUID) -> LumiChatMessage? {
        messages(for: conversationID).last
    }

    func fetchDailyMessageCounts(since: Date) async -> [Date: Int] { [:] }
    func fetchDailyTokenCounts(since: Date) async -> [Date: Int] { [:] }
    func fetchTokenUsage(on day: Date, providerID: String?, modelName: String?) async -> MessageTokenUsage {
        MessageTokenUsage(day: day, inputTokens: 0, outputTokens: 0)
    }

    // MARK: MessageManaging(写,@MainActor)

    @MainActor
    func insertMessage(_ message: LumiChatMessage, to conversationID: UUID) {
        log?.record("insertMessage(\(message.role.rawValue))")
        lock.lock(); defer { lock.unlock() }
        storage[conversationID, default: []].append(message)
    }

    @MainActor
    func deleteMessage(id: UUID, in conversationID: UUID) {}

    @MainActor
    func updateMessage(id: UUID, in conversationID: UUID, content: String) {}

    @MainActor
    func updateToolCallResult(
        _ result: LumiToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID
    ) {}

    @MainActor
    func clearMessages(in conversationID: UUID) {
        lock.lock(); defer { lock.unlock() }
        storage.removeValue(forKey: conversationID)
    }
}
