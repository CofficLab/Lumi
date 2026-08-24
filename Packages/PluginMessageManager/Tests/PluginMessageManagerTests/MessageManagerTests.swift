import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// Write-behind + read-your-writes 行为测试。
///
/// 锁定 `MessageManager` 参考 ChatGPT 策略的写入语义:
/// - insert 后 UI 立即能从读路径看到消息(read-your-writes),不等落盘;
/// - user 消息立即同步落盘,assistant 消息后台落盘;
/// - 后台落盘完成后,消息仍在读路径可见(磁盘已有)。
@MainActor
@Suite("MessageManager Write-Behind")
struct MessageManagerWriteBehindTests {
    private func makeStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageManagerWB-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    private func makeManager(store: MessageStore?) -> MessageManager {
        MessageManager(
            store: store,
            dataDirectory: store.map { _ in URL(fileURLWithPath: NSTemporaryDirectory()) }
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
        )
    }

    @Test("insert 后立即能读到(assistant 走后台落盘,不等盘)")
    func readYourWritesForAssistant() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()

        let msg = Message(
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
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()

        let msg = Message(
            conversationID: conversationID, role: .user,
            content: "hi", createdAt: Date()
        )
        manager.insertMessage(msg, to: conversationID)

        // user 消息同步落盘:绕过 manager,直接查 store 也能立即查到。
        #expect(store.fetchMessages(conversationId: conversationID).count == 1)
    }

    @Test("user 消息落盘成功后发 saved 通知")
    func userMessagePostsSavedNotificationAfterPersistence() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let msg = Message(
            conversationID: conversationID, role: .user,
            content: "hi", createdAt: Date()
        )

        let received = expectationCapture()
        let observer = NotificationCenter.default.addObserver(
            forName: Notification.Name("com.coffic.lumi.messageSaved"),
            object: nil,
            queue: nil
        ) { notification in
            received.conversationID = notification.userInfo?["conversationID"] as? UUID
            received.messageID = notification.userInfo?["messageID"] as? UUID
            received.role = notification.userInfo?["role"] as? String
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        manager.insertMessage(msg, to: conversationID)

        #expect(store.fetchMessages(conversationId: conversationID).contains { $0.id == msg.id })
        #expect(received.conversationID == conversationID)
        #expect(received.messageID == msg.id)
        #expect(received.role == MessageRole.user.rawValue)
    }

    @Test("assistant 消息最终落盘(等后台队列完成后)")
    func assistantEventuallyPersisted() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()

        manager.insertMessage(
            Message(conversationID: conversationID, role: .assistant,
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
        let manager = makeManager(store: nil)
        let conversationID = UUID()

        manager.insertMessage(
            Message(conversationID: conversationID, role: .assistant,
                    content: "no disk", createdAt: Date()),
            to: conversationID
        )

        let page = manager.messagePage(for: conversationID, limit: 10, beforeMessageID: nil, includesToolMessages: false)
        #expect(page.count == 1)
        #expect(page.first?.content == "no disk")
    }

    @Test("活动聚合包含持久化与待落盘消息")
    func dailyActivityAggregates() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        let firstConversation = UUID()
        let secondConversation = UUID()

        manager.insertMessage(
            Message(conversationID: firstConversation, role: .user, content: "saved", createdAt: day, inputTokenCount: 10),
            to: firstConversation
        )
        manager.insertMessage(
            Message(conversationID: secondConversation, role: .assistant, content: "pending", createdAt: day, outputTokenCount: 7),
            to: secondConversation
        )

        #expect(manager.dailyMessageCounts(since: day)[day] == 2)
        #expect(manager.dailyTokenCounts(since: day)[day] == 17)
    }

    private func expectationCapture() -> SavedNotificationCapture {
        SavedNotificationCapture()
    }
}

/// 通知捕获辅助。
private final class SavedNotificationCapture {
    var conversationID: UUID?
    var messageID: UUID?
    var role: String?
}

/// 瞬时 status 消息行为测试。
///
/// 锁定 status 语义:
/// - status 只入内存、不落盘(磁盘查不到);
/// - status 从读路径可见(合并到 messagePage 末尾);
/// - 过程消息(如 user/tool/assistant)不清 status，status 覆盖整个 AgentTurn；
/// - clearStatusMessages 显式清除。
@MainActor
@Suite("MessageManager Status Message")
struct MessageManagerStatusMessageTests {
    private func makeStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageManagerStatus-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    private func makeManager(store: MessageStore?) -> MessageManager {
        MessageManager(
            store: store,
            dataDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        )
    }

    @Test("status 不落盘:磁盘查不到,但读路径可见")
    func statusInMemoryOnly() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()

        manager.insertMessage(
            Message(conversationID: conversationID, role: .status, content: "正在发送…"),
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
        let (_, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: nil)
        let conversationID = UUID()

        func page() -> [Message] {
            manager.messagePage(for: conversationID, limit: 10, beforeMessageID: nil, includesToolMessages: false)
        }
        func hasStatus() -> Bool { page().contains { $0.role == .status } }

        manager.insertMessage(
            Message(conversationID: conversationID, role: .status, content: "正在发送…"),
            to: conversationID
        )
        #expect(hasStatus())

        // user 消息不清 status(user 与 status 同属发送这一轮)。
        manager.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "你好"),
            to: conversationID
        )
        #expect(hasStatus(), "user 消息不应清除 status")

        // 工具结果、过程 assistant 都不能让 status 提前退场。
        manager.insertMessage(
            Message(conversationID: conversationID, role: .tool, content: "工具结果"),
            to: conversationID
        )
        #expect(hasStatus(), "tool 消息不应清除 status")

        manager.insertMessage(
            Message(conversationID: conversationID, role: .assistant, content: "过程回复"),
            to: conversationID
        )
        #expect(hasStatus(), "assistant 消息不应清除 status")

        // 显式清除。
        manager.clearStatusMessages(in: conversationID)
        #expect(!hasStatus(), "clearStatusMessages 应清除 status")
    }
}

/// 分页与删除行为测试。
@MainActor
@Suite("MessageManager Pagination & Delete")
struct MessageManagerPaginationDeleteTests {
    private func makeStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageManagerPage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    private func makeManager(store: MessageStore?) -> MessageManager {
        MessageManager(
            store: store,
            dataDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        )
    }

    @Test("分页:limit 截断 + beforeMessageID 游标")
    func pagination() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()

        for i in 0..<5 {
            let msg = Message(
                conversationID: conversationID, role: .user,
                content: "m\(i)", createdAt: Date().addingTimeInterval(TimeInterval(i))
            )
            manager.insertMessage(msg, to: conversationID)
            // user 同步落盘，落盘后从 pending 移除，读路径从磁盘读。
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        // 最新一页（取最近 2 条）。
        let latest = manager.messagePage(for: conversationID, limit: 2, beforeMessageID: nil, includesToolMessages: true)
        #expect(latest.count == 2)
        #expect(latest.last?.content == "m4")

        // 游标：取 m2 作为锚点 → 更早的 m0/m1。
        let m2 = manager.messages(for: conversationID).first { $0.content == "m2" }!
        let earlier = manager.messagePage(for: conversationID, limit: 10, beforeMessageID: m2.id, includesToolMessages: true)
        #expect(earlier.count == 2)
        #expect(earlier.map(\.content) == ["m0", "m1"])
    }

    @Test("deleteMessage 从磁盘与读路径移除")
    func deleteMessage() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()

        let msg = Message(conversationID: conversationID, role: .user, content: "bye", createdAt: Date())
        manager.insertMessage(msg, to: conversationID)
        try await Task.sleep(nanoseconds: 5_000_000)
        #expect(manager.messageCount(for: conversationID) == 1)

        manager.deleteMessage(id: msg.id, in: conversationID)
        #expect(manager.messageCount(for: conversationID) == 0)
        #expect(manager.messages(for: conversationID).isEmpty)
    }

    @Test("clearMessages 清空磁盘(排空写队列)")
    func clearMessages() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()

        // assistant 走后台落盘，与 clear 竞争：clear 会 drain 队列再删。
        manager.insertMessage(
            Message(conversationID: conversationID, role: .assistant, content: "a1", createdAt: Date()),
            to: conversationID
        )
        manager.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "u1", createdAt: Date()),
            to: conversationID
        )
        try await Task.sleep(nanoseconds: 5_000_000)
        #expect(manager.messageCount(for: conversationID) == 2)

        manager.clearMessages(in: conversationID)
        #expect(manager.messageCount(for: conversationID) == 0)
        #expect(store.fetchMessages(conversationId: conversationID).isEmpty)
    }

    @Test("updateToolCallResult 写入展示快照")
    func updateToolCallResult() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()

        let toolCall = MessageToolCall(id: "call-1", name: "ask_user", arguments: "{}")
        let assistantMsg = Message(
            conversationID: conversationID, role: .assistant,
            content: "ask", createdAt: Date(), toolCalls: [toolCall]
        )
        manager.insertMessage(assistantMsg, to: conversationID)
        try await Task.sleep(nanoseconds: 5_000_000)

        let result = MessageToolResult(content: "user answered yes", isError: false)
        manager.updateToolCallResult(result, toolCallID: "call-1", assistantMessageID: assistantMsg.id, in: conversationID)

        let stored = manager.messages(for: conversationID).first { $0.id == assistantMsg.id }
        #expect(stored?.toolCalls?.first?.result?.content == "user answered yes")
        // 重启后可读（落盘到 toolCallsJson）。
        let fetched = store.fetchMessage(id: assistantMsg.id)
        #expect(fetched?.toolCalls?.first?.result?.content == "user answered yes")
    }
}
