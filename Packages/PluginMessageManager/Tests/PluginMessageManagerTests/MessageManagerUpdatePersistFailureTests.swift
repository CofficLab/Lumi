import Foundation
import ProviderMessage
import SQLite3
import Testing
@testable import PluginMessageManager

/// #151 回归：更新落盘失败时必须保留 pending，否则消息从所有读路径静默消失。
///
/// `persistUpdatedMessage` 旧实现忽略 `store.updateMessage` 的 Bool 返回值，
/// 无条件 `dequeuePending`。当原始 insert 失败（磁盘无记录）、或更新 save 失败时，
/// 消息既不在磁盘也不在内存缓冲，`messages(for:)` 再也读不到它。
///
/// 两个确定性场景（不依赖自然磁盘故障）：
/// - 「insert 失败后 update 失败」：只用 internal `pending` 接缝放入缓冲、不写磁盘，
///   `updateMessage` 找不到记录返回 false。
/// - 「update save 失败」：磁盘已有记录，用 SQLite `BEFORE UPDATE` 触发器让
///   SwiftData 的 save 抛错，`updateMessage` 返回 false。触发器体故意引用一张
///   不存在的表，使 UPDATE 以 `SQLITE_ERROR`（而非 `SQLITE_CONSTRAINT`）失败——
///   后者会被 CoreData 误判为乐观锁冲突并无限重试直至抛出不可捕获的 NSException。
/// 另加成功路径，防止「永远不 dequeue」的过度保留把窗口堵死。
@MainActor
@Suite("MessageManager 更新落盘失败保留 pending")
struct MessageManagerUpdatePersistFailureTests {
    private enum TriggerError: Error {
        case openFailed(Int32)
        case execFailed(String)
    }

    private func makeStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageManagerUpdateFail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    private func makeManager(store: MessageStore) -> MessageManager {
        MessageManager(store: store, dataDirectory: URL(fileURLWithPath: NSTemporaryDirectory()))
    }

    /// 在 messages.sqlite 上装一个 BEFORE UPDATE 触发器，让任何 UPDATE 立即失败。
    /// 触发器体向一张不存在的表 INSERT，使 UPDATE 以 `SQLITE_ERROR` 失败：
    /// SwiftData 的 save 因此抛出可捕获的 NSError → `MessageStore.updateMessage`
    /// 返回 false。不能用 `RAISE(ABORT)`——那会返回 `SQLITE_CONSTRAINT`，被 CoreData
    /// 当成乐观锁冲突无限重试，最终抛出不可捕获的 NSException 让测试进程崩溃。
    private func installUpdateAbortTrigger(at directory: URL) throws {
        let dbURL = directory.appendingPathComponent("messages.sqlite")
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            dbURL.path, &database,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil
        )
        guard openResult == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            throw TriggerError.openFailed(openResult)
        }
        defer { sqlite3_close(database) }

        let sql = """
        CREATE TRIGGER lumi_test_fail_update BEFORE UPDATE ON ZMESSAGEMODEL \
        BEGIN INSERT INTO lumi_no_such_table (x) VALUES (1); END;
        """
        var errorMessage: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(database))
            sqlite3_free(errorMessage)
            throw TriggerError.execFailed(message)
        }
    }

    @Test("insert 失败后 update 找不到磁盘记录：保留 pending，消息仍可读")
    func updateRetainsPendingWhenNoDiskRecord() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let message = Message(
            conversationID: conversationID, role: .assistant,
            content: "A", createdAt: Date()
        )

        // 模拟原始 insert 落盘失败：pending 仍持有消息，但磁盘没有记录。
        manager.pending.enqueue(message, conversationID: conversationID)
        #expect(store.fetchMessages(conversationId: conversationID).isEmpty)

        // 流式更新到 B：命中 pending → 后台 updateMessage 找不到记录返回 false。
        manager.updateMessage(id: message.id, in: conversationID, content: "B")
        manager.flushPendingWrites()

        // 修复前：无条件 dequeue → pending 空 + 磁盘空 → 消息彻底消失。
        let retained = manager.pending.snapshot(for: conversationID)
        #expect(retained.contains { $0.id == message.id && $0.content == "B" })
        #expect(store.fetchMessages(conversationId: conversationID).isEmpty)

        // 读路径（磁盘 + pending 合并）仍能看到最新版本 B。
        let visible = manager.messages(for: conversationID)
        #expect(visible.contains { $0.id == message.id && $0.content == "B" })
    }

    @Test("update save 失败（磁盘已有记录）：保留 pending，磁盘旧内容不被误删")
    func updateRetainsPendingWhenSaveFails() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let message = Message(
            conversationID: conversationID, role: .assistant,
            content: "A", createdAt: Date()
        )

        // 磁盘已有记录 A，同时仍在 write-behind 窗口内（pending 也持有）。
        try store.insertMessage(message)
        manager.pending.enqueue(message, conversationID: conversationID)
        #expect(store.fetchMessage(id: message.id)?.content == "A")

        // 让任何 UPDATE 落盘失败：save 抛错 → updateMessage 返回 false。
        try installUpdateAbortTrigger(at: directory)

        manager.updateMessage(id: message.id, in: conversationID, content: "B")
        manager.flushPendingWrites()

        // 修复前：无条件 dequeue → pending 空，磁盘还是旧 A，B 编辑丢失。
        let retained = manager.pending.snapshot(for: conversationID)
        #expect(retained.contains { $0.id == message.id && $0.content == "B" })
        // save 失败必须回滚，磁盘旧内容仍在（没有被半写覆盖）。
        #expect(store.fetchMessage(id: message.id)?.content == "A")

        // 读路径仍能看到最新版本 B（pending 覆盖磁盘旧版本）。
        let visible = manager.messages(for: conversationID)
        #expect(visible.contains { $0.id == message.id && $0.content == "B" })
    }

    @Test("update 落盘成功：撤掉 pending，磁盘更新为最新内容")
    func updateDequeuesPendingWhenSaveSucceeds() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let message = Message(
            conversationID: conversationID, role: .assistant,
            content: "A", createdAt: Date()
        )

        try store.insertMessage(message)
        manager.pending.enqueue(message, conversationID: conversationID)

        manager.updateMessage(id: message.id, in: conversationID, content: "B")
        manager.flushPendingWrites()

        // 成功路径必须 dequeue，否则 pending 永远堵着、读路径反复 merge 旧脏数据。
        #expect(manager.pending.snapshot(for: conversationID).isEmpty)
        #expect(store.fetchMessage(id: message.id)?.content == "B")
        let visible = manager.messages(for: conversationID)
        #expect(visible.contains { $0.id == message.id && $0.content == "B" })
    }
}