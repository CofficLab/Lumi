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

    @Test("消息落盘成功后发布结构化持久化事件")
    func messageChangePublishesAfterPersistence() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let msg = Message(
            conversationID: conversationID, role: .user,
            content: "hi", createdAt: Date()
        )

        var persistedMessage: Message?
        let handle = manager.addMessageChangeObserver { change in
            guard case let .persisted(message, id) = change,
                  id == conversationID else { return }
            persistedMessage = message
        }
        defer { handle.cancel() }

        manager.insertMessage(msg, to: conversationID)

        var notified = false
        for _ in 0..<100 {
            if store.fetchMessages(conversationId: conversationID).contains(where: { $0.id == msg.id })
                && persistedMessage == msg {
                notified = true
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(notified)
        #expect(persistedMessage == msg)
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

/// 复现：**用户已授权/已拒绝的工具调用，重新打开消息列表又出现授权界面。**
///
/// ## 渲染层的复现判据
///
/// 授权卡片由 `ToolApprovalRowRenderer.canRender` 决定是否渲染，条件是：
///
/// ```
/// authorizationState == "pendingAuthorization"
/// && (result == nil || result.awaitingUserResponse == true)
/// ```
///
/// 因此**只要消息里还留着「等待授权的占位结果 + pendingAuthorization」，
/// 每次重新进入会话都会重新弹出授权界面**——`authorizationState` 缺失（nil）
/// 与 `pendingAuthorization` 在这里等价。
///
/// ## 这一层要锁住什么
///
/// `MessageStore.updateToolCalls` 是 toolCalls 的**唯一覆盖写入口**，
/// 而 `MessageManager.updateToolCallResult` 是它唯一的调用方之一。
/// 只要「用户已决定」这件事在这一层被可靠持久化，重新打开会话就一定
/// 不会再次要求授权。
///
/// - Note: 本组用例锁定的是**持久化层的正确性**（当前应通过）。
///   真正丢失授权状态的是上游 —— `AgentLoopManager.handleAuthorizedToolCompletion`
///   的 guard 会静默 return，根本不调用 `updateToolCallResult`，
///   那由 `ToolAuthorizationPersistenceTests`（PluginAgentLoop）复现。
@MainActor
@Suite("MessageManager 工具授权状态持久化")
struct MessageManagerToolAuthorizationTests {
    private func makeStore(
        _ tag: String
    ) throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageManagerAuth-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    private func makeManager(store: MessageStore?) -> MessageManager {
        MessageManager(
            store: store,
            dataDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        )
    }

    /// 轮询等待 `updateToolCallResult` 的后台覆盖写落到磁盘。
    ///
    /// - Important: 必须等**目标字段**出现，不能只等「消息里有 toolCalls」。
    ///   覆盖写是异步的，过早读到的仍是 insert 时的初始快照，
    ///   会把「授权状态丢失」误判成缺陷。
    private func waitForToolCall(
        _ store: MessageStore,
        messageID: UUID,
        toolCallID: String,
        matching predicate: (MessageToolCall) -> Bool,
        timeoutIterations: Int = 200
    ) async throws -> MessageToolCall? {
        var last: MessageToolCall?
        for _ in 0..<timeoutIterations {
            let call = store.fetchMessage(id: messageID)?
                .toolCalls?
                .first { $0.id == toolCallID }
            if let call {
                last = call
                if predicate(call) { return call }
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return last
    }

    /// 一条处于「等待授权」形态的 assistant 消息。
    ///
    /// 与 `executeBatch(.requireApprovalForHighRisk)` 命中
    /// `needsUserResponse` 后落库的真实形态一致。
    private func pendingApprovalMessage(
        conversationID: UUID,
        toolCallID: String
    ) -> Message {
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: Date(),
            toolCalls: [
                MessageToolCall(
                    id: toolCallID,
                    name: "write_file",
                    arguments: #"{"path":"/tmp/a.txt"}"#,
                    result: MessageToolResult(
                        content: #"{"toolCallId":"approval:\#(toolCallID)","kind":"permission","question":"是否允许？","options":["允许","拒绝"],"mode":"yes_no"}"#,
                        awaitingUserResponse: true,
                        interactionState: .waiting
                    ),
                    authorizationState: "pendingAuthorization"
                )
            ]
        )
    }

    /// 用户点了「允许」后重开消息列表，不应再次要求授权。
    ///
    /// 这是「授权界面重新出现」在持久化层的**正向判据**：
    /// 落库正确 ⇒ 重新打开读到的状态不满足 `canRender` 的两个条件。
    @Test("用户允许后重新打开会话，不再显示授权界面")
    func approvalIsNotPendingAfterReopen() async throws {
        let (store, directory) = try makeStore("approve")
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let toolCallID = "call-approve"
        let assistant = pendingApprovalMessage(
            conversationID: conversationID,
            toolCallID: toolCallID
        )
        manager.insertMessage(assistant, to: conversationID)

        manager.updateToolCallResult(
            MessageToolResult(content: "file written"),
            toolCallID: toolCallID,
            assistantMessageID: assistant.id,
            in: conversationID,
            authorizationState: "userApproved"
        )
        let approved = try await waitForToolCall(
            store,
            messageID: assistant.id,
            toolCallID: toolCallID,
            matching: { $0.authorizationState == "userApproved" }
        )
        #expect(approved?.authorizationState == "userApproved")

        // 重新打开会话：新建 MessageManager 走磁盘读取路径。
        let reopened = MessageManager(
            store: try MessageStore(databaseRootURL: directory),
            dataDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        )
        let call = reopened.messages(for: conversationID)
            .first { $0.id == assistant.id }?
            .toolCalls?
            .first { $0.id == toolCallID }

        // canRender 的两个条件都必须不成立。
        #expect(call?.authorizationState != "pendingAuthorization")
        #expect(call?.result?.awaitingUserResponse == false)
    }

    /// 用户点了「拒绝」后重开消息列表，同样不应再次要求授权。
    ///
    /// 拒绝没有「工具实际执行」带来的结果刷新，因此它是最容易只写一次、
    /// 之后被别处覆盖写抹掉的形态。
    @Test("用户拒绝后重新打开会话，不再显示授权界面")
    func rejectionIsNotPendingAfterReopen() async throws {
        let (store, directory) = try makeStore("reject")
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let toolCallID = "call-reject"
        let assistant = pendingApprovalMessage(
            conversationID: conversationID,
            toolCallID: toolCallID
        )
        manager.insertMessage(assistant, to: conversationID)

        manager.updateToolCallResult(
            MessageToolResult(
                content: "Tool execution was rejected by the user.",
                isError: true
            ),
            toolCallID: toolCallID,
            assistantMessageID: assistant.id,
            in: conversationID,
            authorizationState: "userRejected"
        )
        let rejected = try await waitForToolCall(
            store,
            messageID: assistant.id,
            toolCallID: toolCallID,
            matching: { $0.authorizationState == "userRejected" }
        )
        #expect(rejected?.authorizationState == "userRejected")

        let reopened = MessageManager(
            store: try MessageStore(databaseRootURL: directory),
            dataDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        )
        let call = reopened.messages(for: conversationID)
            .first { $0.id == assistant.id }?
            .toolCalls?
            .first { $0.id == toolCallID }

        #expect(call?.authorizationState == "userRejected")
        #expect(call?.result?.awaitingUserResponse == false)
        #expect(call?.result?.isError == true)
    }

    /// 只更新结果、不带 `authorizationState` 的覆盖写，不能把已决定的授权状态抹掉。
    ///
    /// `MessageStore.updateToolCalls` 是**整体替换** toolCalls 数组的。
    /// `MessageManager.updateToolCallResult` 在 `authorizationState == nil`
    /// 时保留原值，因此这里锁住「空状态不等于回退到未授权」这条语义，
    /// 避免后续重构把 `if let` 简化掉。
    @Test("仅覆盖结果不会把已决定的授权状态清回未授权")
    func overwritingResultKeepsResolvedAuthorizationState() async throws {
        let (store, directory) = try makeStore("overwrite")
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let toolCallID = "call-approve-then-overwrite"
        let assistant = pendingApprovalMessage(
            conversationID: conversationID,
            toolCallID: toolCallID
        )
        manager.insertMessage(assistant, to: conversationID)

        manager.updateToolCallResult(
            MessageToolResult(content: "file written"),
            toolCallID: toolCallID,
            assistantMessageID: assistant.id,
            in: conversationID,
            authorizationState: "userApproved"
        )
        _ = try await waitForToolCall(
            store,
            messageID: assistant.id,
            toolCallID: toolCallID,
            matching: { $0.authorizationState == "userApproved" }
        )

        // 结果从别处（ToolManager 记录恢复 / 渲染层 resolve）被再次覆盖写，
        // 快照没有携带 authorizationState。
        manager.updateToolCallResult(
            MessageToolResult(content: "file written (refreshed)"),
            toolCallID: toolCallID,
            assistantMessageID: assistant.id,
            in: conversationID,
            authorizationState: nil
        )
        let overwritten = try await waitForToolCall(
            store,
            messageID: assistant.id,
            toolCallID: toolCallID,
            matching: { $0.result?.content == "file written (refreshed)" }
        )

        #expect(overwritten?.result?.content == "file written (refreshed)")
        #expect(overwritten?.authorizationState == "userApproved")
    }
}
