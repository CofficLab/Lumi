import Foundation
import LumiKernel
import Testing
@testable import MessageStorePlugin

/// Write-behind + read-your-writes 行为测试。
///
/// 锁定 `MessageManager` 参考 ChatGPT 策略的写入语义:
/// - insert 后 UI 立即能从读路径看到消息(read-your-writes),不等落盘;
/// - user 消息立即同步落盘,assistant 消息后台落盘;
/// - 后台落盘完成后,消息仍在读路径可见(磁盘已有)。
@MainActor
@Suite("MessageManager Write-Behind", .serialized)
struct MessageManagerWriteBehindTests {
    /// 共享桥接单例需在用例间隔离:每个用例装一个临时 store。
    private func installTemporaryStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageManagerWB-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try MessageStore(databaseRootURL: directory)
        MessageStoreRuntimeBridge.shared.store = store
        return (store, directory)
    }

    private func makeManager() -> (MessageManager, LumiKernel) {
        let kernel = LumiKernel()
        let manager = MessageManager(kernel: kernel)
        return (manager, kernel)
    }

    @Test("insert 后立即能读到(assistant 走后台落盘,不等盘)")
    func readYourWritesForAssistant() async throws {
        let (_, directory) = try installTemporaryStore()
        defer {
            MessageStoreRuntimeBridge.shared.store = nil
            try? FileManager.default.removeItem(at: directory)
        }
        let (manager, _) = makeManager()
        let conversationID = UUID()

        let msg = LumiChatMessage(
            conversationID: conversationID, role: .assistant,
            content: "hello", createdAt: Date()
        )
        manager.insertMessage(msg, to: conversationID)

        // 后台落盘可能尚未完成,但读路径必须立即看到(read-your-writes)。
        let page = manager.messagePage(for: conversationID, limit: 10, beforeMessageID: nil, includesToolMessages: false)
        #expect(page.count == 1)
        #expect(page.first?.content == "hello")
    }

    @Test("user 消息立即同步落盘")
    func userMessagePersistedEagerly() async throws {
        let (store, directory) = try installTemporaryStore()
        defer {
            MessageStoreRuntimeBridge.shared.store = nil
            try? FileManager.default.removeItem(at: directory)
        }
        let (manager, _) = makeManager()
        let conversationID = UUID()

        let msg = LumiChatMessage(
            conversationID: conversationID, role: .user,
            content: "hi", createdAt: Date()
        )
        manager.insertMessage(msg, to: conversationID)

        // user 消息同步落盘:绕过 manager,直接查 store 也能立即查到。
        #expect(store.fetchMessages(conversationId: conversationID).count == 1)
    }

    @Test("assistant 消息最终落盘(等后台队列完成后)")
    func assistantEventuallyPersisted() async throws {
        let (store, directory) = try installTemporaryStore()
        defer {
            MessageStoreRuntimeBridge.shared.store = nil
            try? FileManager.default.removeItem(at: directory)
        }
        let (manager, _) = makeManager()
        let conversationID = UUID()

        manager.insertMessage(
            LumiChatMessage(conversationID: conversationID, role: .assistant,
                            content: "delayed", createdAt: Date()),
            to: conversationID
        )

        // 轮询等后台落盘完成(串行队列,通常很快)。
        var persisted = false
        for _ in 0..<100 {
            if store.fetchMessages(conversationId: conversationID).count == 1 {
                persisted = true
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(persisted)
    }

    @Test("store 不可用时,assistant 消息仍可从内存读路径读到(优雅降级)")
    func readableEvenWhenStoreUnavailable() async throws {
        // 不安装任何 store —— 直接无磁盘。本用例不触发临时目录创建,避免影响其它用例。
        let previousStore = MessageStoreRuntimeBridge.shared.store
        MessageStoreRuntimeBridge.shared.store = nil
        defer { MessageStoreRuntimeBridge.shared.store = previousStore }

        let (manager, _) = makeManager()
        let conversationID = UUID()

        manager.insertMessage(
            LumiChatMessage(conversationID: conversationID, role: .assistant,
                            content: "no disk", createdAt: Date()),
            to: conversationID
        )

        let page = manager.messagePage(for: conversationID, limit: 10, beforeMessageID: nil, includesToolMessages: false)
        #expect(page.count == 1)
        #expect(page.first?.content == "no disk")
    }
}
