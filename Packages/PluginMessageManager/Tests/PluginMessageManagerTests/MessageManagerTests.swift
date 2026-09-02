import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// Write-behind + read-your-writes 行为测试。
///
/// 锁定 `MessageManager` 参考 ChatGPT 策略的写入语义:
/// - insert 后 UI 立即能从读路径看到消息(read-your-writes),不等落盘;
/// - user / assistant 消息后台落盘;
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

    @Test("结构化插入事件在后台落盘前同步发布")
    func messageChangePublishesBeforePersistence() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        var observed: Message?
        let handle = manager.addMessageChangeObserver { change in
            guard case let .inserted(message, id) = change, id == conversationID else { return }
            observed = message
        }
        defer { handle.cancel() }

        let message = Message(
            conversationID: conversationID,
            role: .user,
            content: "instant"
        )
        manager.insertMessage(message, to: conversationID)

        #expect(observed == message)
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

        var persisted = false
        for _ in 0..<100 {
            if store.fetchMessages(conversationId: conversationID).contains(where: { $0.id == msg.id }) {
                persisted = true
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(persisted)
    }

    @Test("异步消息快照包含待落盘消息")
    func asyncSnapshotIncludesPendingMessage() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let message = Message(
            conversationID: conversationID,
            role: .user,
            content: "background snapshot"
        )

        manager.insertMessage(message, to: conversationID)
        let snapshot = await manager.messagesSnapshot(in: conversationID)

        #expect(snapshot.contains { $0.id == message.id && $0.content == message.content })
        #expect(await manager.firstUserMessage(in: conversationID)?.id == message.id)
    }

    @Test("user 消息立即可读并最终后台落盘")
    func userMessagePersistedInBackground() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()

        let msg = Message(
            conversationID: conversationID, role: .user,
            content: "hi", createdAt: Date()
        )
        manager.insertMessage(msg, to: conversationID)

        // user 消息先进入 pending:绕过 manager 的读路径暂时不要求立即可见。
        let page = manager.messagePage(
            for: conversationID,
            limit: 10,
            beforeMessageID: nil,
            includesToolMessages: false
        )
        #expect(page.count == 1)
        #expect(page.first?.content == "hi")

        var persisted = false
        for _ in 0..<100 {
            if store.fetchMessages(conversationId: conversationID).contains(where: { $0.id == msg.id }) {
                persisted = true
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(persisted)
    }

    @Test("LLM 历史读取包含磁盘与 pending 消息")
    func llmHistoryIncludesPendingMessages() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()

        let message = Message(
            conversationID: conversationID,
            role: .user,
            content: "context",
            createdAt: Date()
        )
        manager.insertMessage(message, to: conversationID)

        let history = await manager.messagesForLLM(in: conversationID)

        #expect(history.map(\.content) == ["context"])
    }

    @Test("响应元数据字段可完整往返数据库")
    func responseMetadataRoundTrips() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()
        let message = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "ok",
            cachedInputTokenCount: 11,
            cacheWriteInputTokenCount: 3,
            cacheTotalInputTokenCount: 14,
            responseID: "resp-1",
            requestID: "req-1",
            rawResponseJSON: "{\"id\":\"resp-1\"}",
            rawStreamEventsJSON: "[\"message_start\"]",
            stopReason: "end_turn"
        )

        try store.insertMessage(message)
        let restored = try #require(store.fetchMessages(conversationId: conversationID).first)

        #expect(restored.cachedInputTokenCount == 11)
        #expect(restored.cacheWriteInputTokenCount == 3)
        #expect(restored.cacheTotalInputTokenCount == 14)
        #expect(restored.responseID == "resp-1")
        #expect(restored.requestID == "req-1")
        #expect(restored.rawResponseJSON == "{\"id\":\"resp-1\"}")
        #expect(restored.rawStreamEventsJSON == "[\"message_start\"]")
        #expect(restored.stopReason == "end_turn")
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
            guard notification.userInfo?["messageID"] as? UUID == msg.id else { return }
            received.conversationID = notification.userInfo?["conversationID"] as? UUID
            received.messageID = notification.userInfo?["messageID"] as? UUID
            received.role = notification.userInfo?["role"] as? String
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        manager.insertMessage(msg, to: conversationID)

        var notified = false
        for _ in 0..<100 {
            if store.fetchMessages(conversationId: conversationID).contains(where: { $0.id == msg.id })
                && received.conversationID == conversationID
                && received.messageID == msg.id
                && received.role == MessageRole.user.rawValue {
                notified = true
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(notified)
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

    @Test("error 消息也先进入 pending，再由 utility 队列落盘")
    func errorEventuallyPersisted() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let message = Message(
            conversationID: conversationID,
            role: .error,
            content: "temporary failure"
        )

        manager.insertMessage(message, to: conversationID)

        let page = manager.messagePage(
            for: conversationID,
            limit: 10,
            beforeMessageID: nil,
            includesToolMessages: false
        )
        #expect(page.map(\.id) == [message.id])

        var persisted = false
        for _ in 0..<100 {
            if store.fetchMessages(conversationId: conversationID).contains(where: { $0.id == message.id }) {
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
    func dailyActivityAggregates() async throws {
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
        #expect(await manager.dailyMessageCountsAsync(since: day)[day] == 2)
        #expect(await manager.dailyTokenCountsAsync(since: day)[day] == 17)

        // 后台写入完成后再清理临时数据库，避免测试结束时队列仍在写入。
        var persisted = false
        for _ in 0..<100 {
            if store.fetchMessages(conversationId: firstConversation).count == 1,
               store.fetchMessages(conversationId: secondConversation).count == 1 {
                persisted = true
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(persisted)
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

    @Test("异步分页包含 pending 消息并遵守游标")
    func asyncPagination() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()

        for index in 0..<5 {
            manager.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: "m\(index)",
                    createdAt: Date(timeIntervalSince1970: TimeInterval(index))
                ),
                to: conversationID
            )
        }

        let latest = await manager.messagePageAsync(
            for: conversationID,
            limit: 2,
            beforeMessageID: nil,
            includesToolMessages: false
        )
        #expect(latest.map(\.content) == ["m3", "m4"])

        let anchor = try #require(latest.first)
        let earlier = await manager.messagePageAsync(
            for: conversationID,
            limit: 2,
            beforeMessageID: anchor.id,
            includesToolMessages: false
        )
        #expect(earlier.map(\.content) == ["m1", "m2"])
        #expect(await manager.hasEarlierMessagesAsync(
            for: conversationID,
            beforeMessageID: anchor.id,
            includesToolMessages: false
        ))
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

        let toolCall = MessageToolCall(
            id: "call-1",
            name: "ask_user",
            arguments: "{}",
            authorizationState: "pendingAuthorization"
        )
        let assistantMsg = Message(
            conversationID: conversationID, role: .assistant,
            content: "ask", createdAt: Date(), toolCalls: [toolCall]
        )
        manager.insertMessage(assistantMsg, to: conversationID)
        try await Task.sleep(nanoseconds: 5_000_000)

        let result = MessageToolResult(content: "user answered yes", isError: false)
        manager.updateToolCallResult(
            result,
            toolCallID: "call-1",
            assistantMessageID: assistantMsg.id,
            in: conversationID,
            authorizationState: "userApproved"
        )

        let stored = manager.messages(for: conversationID).first { $0.id == assistantMsg.id }
        #expect(stored?.toolCalls?.first?.result?.content == "user answered yes")
        #expect(stored?.toolCalls?.first?.authorizationState == "userApproved")
        // 重启后可读（落盘到 toolCallsJson）。
        let fetched = store.fetchMessage(id: assistantMsg.id)
        #expect(fetched?.toolCalls?.first?.result?.content == "user answered yes")
        #expect(fetched?.toolCalls?.first?.authorizationState == "userApproved")
    }
}
