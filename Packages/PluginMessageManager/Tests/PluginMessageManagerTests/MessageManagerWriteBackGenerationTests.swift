import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// 线程安全布尔标志：后台线程写、MainActor 测试体用 `await Task.sleep` 轮询读。
private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.lock(); value = true; lock.unlock() }
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

/// #150 回归：写回队列按代次门控 dequeue，旧写回不得撤掉已更新的新 pending，
/// 后续更新也不得在队列里的旧更新完成前绕过队列走同步磁盘写。
///
/// 旧实现 insert 成功后按 id 无条件 `dequeuePending`，会把已经更新到 B 的 pending
/// 撤掉；此时再更新到 C 因 pending 为空走同步 `store.updateMessage`，抢在仍排在
/// 队列里的 update(B) 之前落盘，随后 update(B) 把磁盘覆盖回 B——重启后仍是旧内容。
///
/// 用「可挂起队列 + 受控存储锁」确定性复现 A→B→C 交错：占住存储锁让 insert(A)
/// 卡住、update(B) 排在其后；挂起队列后放行存储锁，insert(A) 落盘并 dequeue，
/// update(B) 因挂起不启动；此刻更新到 C，再放行队列排空，断言磁盘最终是 C。
@MainActor
@Suite("MessageManager 写回代次门控")
struct MessageManagerWriteBackGenerationTests {
    private func makeStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageManagerGen-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    private func makeManager(store: MessageStore) -> MessageManager {
        MessageManager(store: store, dataDirectory: URL(fileURLWithPath: NSTemporaryDirectory()))
    }

    /// 后台线程占住存储锁，模拟磁盘写入被阻塞，直到测试放行（不占用 MainActor）。
    private func holdStoreLock(_ store: MessageStore) -> (gateHeld: Flag, release: DispatchSemaphore) {
        let gateHeld = Flag()
        let release = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            store.lock.lock()
            gateHeld.set()
            release.wait()
            store.lock.unlock()
        }
        return (gateHeld, release)
    }

    private func waitUntil(_ flag: Flag, timeoutNanoseconds: UInt64 = 30_000_000_000) async throws -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if flag.isSet { return true }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        return flag.isSet
    }

    /// 轮询磁盘直到某条消息正文等于期望值（确认 insert(A) 已真正落盘）。
    /// 超时放宽到 30s：并行跑整套时 utility 落盘队列可能被其它套件抢占 CPU。
    private func waitUntilDiskContent(
        _ store: MessageStore, id: UUID, equals expected: String,
        timeoutNanoseconds: UInt64 = 30_000_000_000
    ) async throws -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if store.fetchMessage(id: id)?.content == expected { return true }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        return store.fetchMessage(id: id)?.content == expected
    }

    @Test("A→B→C 交错：旧 insert 不得撤掉新 pending，磁盘最终是 C")
    func writeBackKeepsLatestContentAcrossABCInterleaving() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let message = Message(
            conversationID: conversationID, role: .assistant,
            content: "A", createdAt: Date()
        )

        let (gateHeld, release) = holdStoreLock(store)
        #expect(try await waitUntil(gateHeld))

        // 保证无论断言成败都把队列恢复，避免挂起的队列被释放时崩溃。
        var suspended = false
        defer { if suspended { manager.persistQueue.resume() } }

        // 1. insert A：落盘块卡在存储锁上，pending=A(gen1)。
        manager.insertMessage(message, to: conversationID)
        // 2. insert 执行前更新到 B：命中 pending → pending=B(gen2)，update(B) 排在 insert(A) 之后。
        manager.updateMessage(id: message.id, in: conversationID, content: "B")

        // 先让 utility 落盘队列真正调度起 insert(A) 并卡在存储锁上，再挂起队列。
        // 否则并行跑整套时 insert(A) 可能尚未启动就被挂起，永远不会落盘 A。
        try await Task.sleep(nanoseconds: 500_000_000)
        // 挂起队列：insert(A) 完成后 update(B) 不会启动，构造「insert 已落盘、update 仍在队列」窗口。
        manager.persistQueue.suspend()
        suspended = true
        // 放行存储锁 → insert(A) 落盘 A 并做代次门控 dequeue；update(B) 仍被挂起。
        release.signal()
        #expect(try await waitUntilDiskContent(store, id: message.id, equals: "A"))
        // 留一点时间让 insert(A) 块收尾（dequeue 在写盘之后同步执行）。
        try await Task.sleep(nanoseconds: 50_000_000)

        // 3. 更新到 C：修复后 pending 仍是 B(gen2) → 命中 → update(C) 入队(gen3)；
        //    修复前 pending 已被 insert(A) 按 id 撤掉 → C 走同步磁盘写，抢在 update(B) 前。
        manager.updateMessage(id: message.id, in: conversationID, content: "C")

        // 放行队列：update(B) → update(C) 依次落盘，最终必须是 C。
        manager.persistQueue.resume()
        suspended = false
        manager.flushPendingWrites()

        #expect(store.fetchMessage(id: message.id)?.content == "C")
        #expect(manager.pending.snapshot(for: conversationID).isEmpty)
    }

    @Test("工具调用未命中也排空被 bump 的代次，pending 不泄漏")
    func toolCallMissStillDrainsPendingGeneration() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let toolCallID = "call-real"
        let assistant = Message(
            conversationID: conversationID, role: .assistant,
            content: "ask", createdAt: Date(),
            toolCalls: [
                MessageToolCall(id: toolCallID, name: "write_file", arguments: "{}")
            ]
        )

        let (gateHeld, release) = holdStoreLock(store)
        #expect(try await waitUntil(gateHeld))

        // insert 卡在锁上 → assistant 仍在 pending。
        manager.insertMessage(assistant, to: conversationID)
        // 写回一个不存在的 toolCallID：命中 pending 但 transform 提前返回（无改动），
        // 代次仍被 bump；必须把原 toolCalls 原样入队消费掉这一代，否则 pending 永久泄漏。
        manager.updateToolCallResult(
            MessageToolResult(content: "ignored"),
            toolCallID: "call-missing",
            assistantMessageID: assistant.id,
            in: conversationID
        )

        release.signal()
        manager.flushPendingWrites()

        // 代次被一次排空写消费 → pending 清空；磁盘 toolCalls 保持原样、未被写入无关结果。
        #expect(manager.pending.snapshot(for: conversationID).isEmpty)
        let stored = store.fetchMessage(id: assistant.id)
        #expect(stored?.toolCalls?.first?.id == toolCallID)
        #expect(stored?.toolCalls?.first?.result == nil)
    }

    @Test("代次门控 dequeue：旧代次不撤新 pending，匹配代次才撤")
    func gatedDequeueOnlyRemovesMatchingGeneration() throws {
        let buffer = PendingMessageBuffer()
        let conversationID = UUID()
        let message = Message(
            conversationID: conversationID, role: .assistant,
            content: "A", createdAt: Date()
        )

        let gen1 = buffer.enqueue(message, conversationID: conversationID)
        let updated = buffer.update(id: message.id, conversationID: conversationID) { $0.content = "B" }
        let gen2 = try #require(updated?.generation)
        #expect(gen2 != gen1)

        // 旧 insert 写回携带 gen1：不得撤掉已更新到 B(gen2) 的 pending。
        buffer.dequeue(id: message.id, conversationID: conversationID, generation: gen1)
        #expect(buffer.snapshot(for: conversationID).contains { $0.id == message.id && $0.content == "B" })

        // 匹配 gen2 的写回才撤掉。
        buffer.dequeue(id: message.id, conversationID: conversationID, generation: gen2)
        #expect(buffer.snapshot(for: conversationID).isEmpty)
    }

    @Test("重复同值更新仍推进代次，最新一代写回后 pending 清空")
    func duplicateUpdateStillResolvesLatestGeneration() throws {
        let buffer = PendingMessageBuffer()
        let conversationID = UUID()
        let message = Message(
            conversationID: conversationID, role: .assistant,
            content: "A", createdAt: Date()
        )

        _ = buffer.enqueue(message, conversationID: conversationID)
        let first = buffer.update(id: message.id, conversationID: conversationID) { $0.content = "B" }
        let genB1 = try #require(first?.generation)
        // 重复写回同样的 B：无条件 bump，避免「值未变就不 bump」让上一代写回成为孤儿。
        let second = buffer.update(id: message.id, conversationID: conversationID) { $0.content = "B" }
        let genB2 = try #require(second?.generation)
        #expect(genB2 != genB1)

        buffer.dequeue(id: message.id, conversationID: conversationID, generation: genB1)
        #expect(buffer.snapshot(for: conversationID).contains { $0.id == message.id })
        buffer.dequeue(id: message.id, conversationID: conversationID, generation: genB2)
        #expect(buffer.snapshot(for: conversationID).isEmpty)
    }
}