import Foundation
import KernelLumi
import Testing
@testable import MessageManagerPlugin

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

    private func makeManager() -> (MessageManager, KernelLumi) {
        let kernel = KernelLumi()
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

    @Test("user 消息落盘成功后发 saved 通知")
    func userMessagePostsSavedNotificationAfterPersistence() async throws {
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
        let capture = MessageSavedNotificationCapture()
        let observer = NotificationCenter.default.addObserver(
            forName: .lumiMessageSaved,
            object: nil,
            queue: nil
        ) { notification in
            capture.record(notification)
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        manager.insertMessage(msg, to: conversationID)

        #expect(store.fetchMessages(conversationId: conversationID).contains { $0.id == msg.id })
        #expect(capture.conversationID == conversationID)
        #expect(capture.messageID == msg.id)
        #expect(capture.role == LumiChatMessageRole.user.rawValue)
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

/// 瞬时 status 消息行为测试。
///
/// 锁定 status 走 insert 模式后的语义:
/// - status 只入内存、不落盘(磁盘查不到);
/// - status 从读路径可见(合并到 messagePage 末尾);
/// - user/assistant/tool/error 都不清 status，status 覆盖整个 AgentTurn；
/// - clearStatusMessage 显式清除(取消等场景兜底)。
@MainActor
@Suite("MessageManager Status Message", .serialized)
struct MessageManagerStatusMessageTests {
    private func installTemporaryStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageManagerStatus-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try MessageStore(databaseRootURL: directory)
        MessageStoreRuntimeBridge.shared.store = store
        return (store, directory)
    }

    private func makeManager() -> MessageManager {
        MessageManager(kernel: KernelLumi())
    }

    @Test("status 不落盘:磁盘查不到,但读路径可见")
    func statusInMemoryOnly() async throws {
        let (store, directory) = try installTemporaryStore()
        defer {
            MessageStoreRuntimeBridge.shared.store = nil
            try? FileManager.default.removeItem(at: directory)
        }
        let manager = makeManager()
        let conversationID = UUID()

        manager.insertMessage(
            LumiChatMessage(conversationID: conversationID, role: .status, content: "正在发送…"),
            to: conversationID
        )

        // 磁盘没有 status(绕过 manager 直接查 store)。
        #expect(store.fetchMessages(conversationId: conversationID).isEmpty)
        // 读路径能看到 status(合并到末尾)。
        let page = manager.messagePage(for: conversationID, limit: 10, beforeMessageID: nil, includesToolMessages: false)
        #expect(page.count == 1)
        #expect(page.first?.role == .status)
    }

    @Test("回合过程消息不清 status")
    func turnProcessMessagesKeepStatus() async throws {
        let (_, directory) = try installTemporaryStore()
        defer {
            MessageStoreRuntimeBridge.shared.store = nil
            try? FileManager.default.removeItem(at: directory)
        }
        let manager = makeManager()
        let conversationID = UUID()

        func page() -> [LumiChatMessage] {
            manager.messagePage(for: conversationID, limit: 10, beforeMessageID: nil, includesToolMessages: false)
        }
        func hasStatus() -> Bool { page().contains { $0.role == .status } }

        manager.insertMessage(
            LumiChatMessage(conversationID: conversationID, role: .status, content: "正在发送…"),
            to: conversationID
        )
        #expect(hasStatus())

        // user 消息不清 status(user 与 status 同属发送这一轮)。
        manager.insertMessage(
            LumiChatMessage(conversationID: conversationID, role: .user, content: "你好"),
            to: conversationID
        )
        #expect(hasStatus(), "user 消息不应清除 status")

        // 重新 insert 一条 status(模拟工具执行前 runner insert)。
        manager.insertMessage(
            LumiChatMessage(conversationID: conversationID, role: .status, content: "正在执行工具…"),
            to: conversationID
        )
        #expect(hasStatus())

        // 工具结果、过程 assistant 和 error 都不能让 status 提前退场；
        // AgentTurn 结束时由生命周期显式清理。
        manager.insertMessage(
            LumiChatMessage(conversationID: conversationID, role: .tool, content: "工具结果"),
            to: conversationID
        )
        #expect(hasStatus(), "tool 消息不应清除 status")

        manager.insertMessage(
            LumiChatMessage(conversationID: conversationID, role: .assistant, content: "过程回复"),
            to: conversationID
        )
        #expect(hasStatus(), "assistant 消息不应清除 status")

        manager.insertMessage(
            LumiChatMessage(conversationID: conversationID, role: .error, content: "失败"),
            to: conversationID
        )
        #expect(hasStatus(), "error 消息不应清除 status")
    }

    @Test("clearStatusMessage 显式清除(取消场景兜底)")
    func clearStatusExplicitly() async throws {
        let (_, directory) = try installTemporaryStore()
        defer {
            MessageStoreRuntimeBridge.shared.store = nil
            try? FileManager.default.removeItem(at: directory)
        }
        let manager = makeManager()
        let conversationID = UUID()

        manager.insertMessage(
            LumiChatMessage(conversationID: conversationID, role: .status, content: "正在发送…"),
            to: conversationID
        )
        #expect(manager.messagePage(for: conversationID, limit: 10, beforeMessageID: nil, includesToolMessages: false).count == 1)

        manager.clearStatusMessage(in: conversationID)

        #expect(manager.messagePage(for: conversationID, limit: 10, beforeMessageID: nil, includesToolMessages: false).isEmpty)
    }

    @Test("同会话多次 insert status 只保留最新一条")
    func statusReplacesPrevious() async throws {
        let (_, directory) = try installTemporaryStore()
        defer {
            MessageStoreRuntimeBridge.shared.store = nil
            try? FileManager.default.removeItem(at: directory)
        }
        let manager = makeManager()
        let conversationID = UUID()

        manager.insertMessage(
            LumiChatMessage(conversationID: conversationID, role: .status, content: "第一"),
            to: conversationID
        )
        manager.insertMessage(
            LumiChatMessage(conversationID: conversationID, role: .status, content: "第二"),
            to: conversationID
        )

        let page = manager.messagePage(for: conversationID, limit: 10, beforeMessageID: nil, includesToolMessages: false)
        let statuses = page.filter { $0.role == .status }
        #expect(statuses.count == 1)
        #expect(statuses.first?.content == "第二")
    }
}

private final class MessageSavedNotificationCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var storedConversationID: UUID?
    private var storedMessageID: UUID?
    private var storedRole: String?

    var conversationID: UUID? {
        lock.withLock { storedConversationID }
    }

    var messageID: UUID? {
        lock.withLock { storedMessageID }
    }

    var role: String? {
        lock.withLock { storedRole }
    }

    func record(_ notification: Notification) {
        lock.withLock {
            storedConversationID = notification.userInfo?[LumiMessageSavedNotification.conversationIDKey] as? UUID
            storedMessageID = notification.userInfo?[LumiMessageSavedNotification.messageIDKey] as? UUID
            storedRole = notification.userInfo?[LumiMessageSavedNotification.roleKey] as? String
        }
    }
}
