import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// 线程安全布尔标志：后台线程写、MainActor 测试体用 `await Task.sleep` 轮询读，
/// 不在 MainActor 上阻塞等待信号量。
private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.lock(); value = true; lock.unlock() }
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

/// 线程安全消息数组容器：flush 线程落盘后写入，测试体读取。
private final class MessageBox: @unchecked Sendable {
    private let lock = NSLock()
    private var messages: [Message] = []
    func set(_ value: [Message]) { lock.lock(); messages = value; lock.unlock() }
    var value: [Message] { lock.lock(); defer { lock.unlock() }; return messages }
}

/// #152 回归：内核停止 / 插件卸载时必须排空 write-behind 落盘队列。
///
/// 用「受控阻塞队列」证明：占住存储锁让后台落盘卡住时，`flushPendingWrites()`
/// 不会提前返回；放行后 flush 返回时所有已接受消息都已落盘、pending 已清空。
/// 修复前 `onShutdown` 为空、无 flush，最后一条消息正常退出即丢失。
@MainActor
@Suite("MessageManager 停止排空 write-behind")
struct MessageManagerShutdownFlushTests {
    private func makeStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageManagerFlush-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    private func makeManager(store: MessageStore) -> MessageManager {
        MessageManager(store: store, dataDirectory: URL(fileURLWithPath: NSTemporaryDirectory()))
    }

    /// 在后台线程占住存储锁，模拟「磁盘写入被阻塞」，直到测试放行。
    ///
    /// `MessageStore.lock` 是 internal（专供测试占锁）。后台落盘块调用
    /// `store.insertMessage` 会卡在这把锁上，从而把 persistQueue 受控地阻塞住。
    /// 锁在后台线程持有 / 释放，不占用 MainActor，避免与 flush 的同步排空死锁。
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

    /// 非阻塞轮询等待标志置位（MainActor 友好，不用信号量阻塞主线程）。
    private func waitUntil(_ flag: Flag, timeoutNanoseconds: UInt64 = 5_000_000_000) async throws -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if flag.isSet { return true }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        return flag.isSet
    }

    @Test("flush 等待被阻塞的落盘收敛后才返回，返回时消息已落盘")
    func flushWaitsForBlockedWriteThenDurable() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let message = Message(
            conversationID: conversationID, role: .user,
            content: "last exchange", createdAt: Date()
        )

        let (gateHeld, release) = holdStoreLock(store)
        #expect(try await waitUntil(gateHeld))

        // 接受消息：进 pending + 后台落盘（落盘卡在存储锁上）。
        manager.insertMessage(message, to: conversationID)

        // 后台调用 flush：必须等落盘收敛才返回（nonisolated，不跳 MainActor）。
        let flushReturned = Flag()
        let disk = MessageBox()
        Thread.detachNewThread {
            manager.flushPendingWrites()
            // 立即标记 flush 已返回——必须在读磁盘之前。否则读磁盘会卡在存储锁上，
            // 把「flush 提前返回」误判成「仍在等待」，no-op flush 也能蒙混过关。
            flushReturned.set()
            disk.set(store.fetchMessages(conversationId: conversationID))
        }

        // 放行前 flush 不可能返回——写入仍被锁阻塞。
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(!flushReturned.isSet)

        // 放行写入 → flush 必须返回，且返回时磁盘已含该消息、pending 已清空。
        release.signal()
        #expect(try await waitUntil(flushReturned))
        #expect(disk.value.contains { $0.id == message.id })
        #expect(manager.pending.snapshot(for: conversationID).isEmpty)
    }

    @Test("flush 同样排空工具结果写回，返回时工具结果已落盘")
    func flushDrainsToolResultWriteBehind() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let toolCallID = "call-flush"
        let assistant = Message(
            conversationID: conversationID, role: .assistant,
            content: "ask", createdAt: Date(),
            toolCalls: [
                MessageToolCall(
                    id: toolCallID, name: "write_file", arguments: "{}",
                    authorizationState: "pendingAuthorization"
                )
            ]
        )

        let (gateHeld, release) = holdStoreLock(store)
        #expect(try await waitUntil(gateHeld))

        manager.insertMessage(assistant, to: conversationID)
        // assistant 仍在 pending（落盘被阻塞）→ 命中 pending 分支，工具结果走后台覆盖写。
        manager.updateToolCallResult(
            MessageToolResult(content: "file written"),
            toolCallID: toolCallID,
            assistantMessageID: assistant.id,
            in: conversationID,
            authorizationState: "userApproved"
        )

        let flushReturned = Flag()
        let disk = MessageBox()
        Thread.detachNewThread {
            manager.flushPendingWrites()
            // 立即标记 flush 已返回——必须在读磁盘之前。否则读磁盘会卡在存储锁上，
            // 把「flush 提前返回」误判成「仍在等待」，no-op flush 也能蒙混过关。
            flushReturned.set()
            disk.set(store.fetchMessages(conversationId: conversationID))
        }

        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(!flushReturned.isSet)

        release.signal()
        #expect(try await waitUntil(flushReturned))
        let stored = disk.value.first { $0.id == assistant.id }
        #expect(stored?.toolCalls?.first?.result?.content == "file written")
        #expect(stored?.toolCalls?.first?.authorizationState == "userApproved")
    }

    @Test("flush 后批量消息全部落盘且 pending 清空")
    func flushConvergesBatchAndEmptiesPending() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        var ids: [UUID] = []
        for index in 0..<5 {
            let message = Message(
                conversationID: conversationID,
                role: index.isMultiple(of: 2) ? .user : .assistant,
                content: "m\(index)",
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
            ids.append(message.id)
            manager.insertMessage(message, to: conversationID)
        }

        // 同步排空：返回时串行队列里此前 enqueue 的写入必须全部收敛。
        manager.flushPendingWrites()

        let disk = store.fetchMessages(conversationId: conversationID)
        #expect(disk.count == 5)
        for id in ids {
            #expect(disk.contains { $0.id == id })
        }
        #expect(manager.pending.snapshot(for: conversationID).isEmpty)
    }
}