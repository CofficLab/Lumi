import Foundation
import Testing
import LumiKernel
@testable import MessageListAppKitPlugin

/// Serialized: these tests rely on MainActor-scheduled subscription work and
/// must not interleave with other suites' MainActor tests (e.g. window layout
/// in the cell-reuse suite), which starves their coalesced tasks.
@Suite(.serialized)
@MainActor
struct AppKitMessageListIntegrationTests {
    @MainActor
    private struct Harness {
        let conversationA = UUID()
        let conversationB = UUID()
        let turnA = UUID()
        let messages: MockMessageManager
        let turns: MockAgentTurnManager
        let conversations: MockConversationManager
        let streaming: MockMessageStreaming
        let coordinator: AppKitMessageListCoordinator

        init(
            pageSize: Int = 40,
            verbosity: LumiResponseVerbosity = .standard
        ) {
            messages = MockMessageManager()
            turns = MockAgentTurnManager()
            conversations = MockConversationManager()
            conversations.globalVerbosity = verbosity
            streaming = MockMessageStreaming()
            coordinator = AppKitMessageListCoordinator(
                dependencies: .init(
                    conversations: conversations,
                    messageManager: messages,
                    agentTurnManager: turns,
                    messageStreaming: streaming,
                    messageSender: nil
                ),
                pageSize: pageSize
            )
        }

        @discardableResult
        func makeMessage(
            conversationID: UUID,
            role: LumiChatMessageRole = .assistant,
            content: String,
            at seconds: Double,
            turnID: UUID? = nil,
            idSuffix: Int
        ) -> LumiChatMessage {
            let id = UUID(uuidString: String(
                format: "%08X-0000-0000-0000-0000000000%02d", idSuffix, idSuffix % 100
            )) ?? UUID()
            let message = LumiChatMessage(
                id: id,
                conversationID: conversationID,
                role: role,
                content: content,
                turnID: turnID,
                createdAt: Date(timeIntervalSinceReferenceDate: seconds)
            )
            messages.seed([message], conversationID: conversationID)
            return message
        }
    }

    // MARK: - First page load

    @Test("首屏加载：快照包含最新一页并按时间升序")
    func firstPageLoad() async throws {
        let h = Harness()
        for i in 0..<10 {
            h.makeMessage(conversationID: h.conversationA, content: "msg \(i)", at: 100 + Double(i), idSuffix: i)
        }
        await h.coordinator.activate(conversationID: h.conversationA)

        let snapshot = h.coordinator.latestSnapshot
        #expect(snapshot.conversationID == h.conversationA)
        #expect(snapshot.rows.count == 10)
        #expect(snapshot.rows.first?.content == "msg 0")
        #expect(snapshot.rows.last?.content == "msg 9")
    }

    @Test("无会话时快照为空")
    func nilConversationYieldsEmpty() async {
        let h = Harness()
        await h.coordinator.activate(conversationID: nil)
        #expect(h.coordinator.latestSnapshot.isEmpty)
    }

    // MARK: - Prepend cursor

    @Test("向上翻页：prepend 更早一页并返回锚点 ID")
    func loadEarlierPrependsAndReturnsAnchor() async {
        let h = Harness(pageSize: 3)
        // 6 条消息：0..5，最新 3 条（3,4,5）在首屏。
        for i in 0..<6 {
            h.makeMessage(conversationID: h.conversationA, content: "msg \(i)", at: 100 + Double(i), idSuffix: i)
        }
        await h.coordinator.activate(conversationID: h.conversationA)

        #expect(h.coordinator.latestSnapshot.rows.count == 3)
        #expect(h.coordinator.latestSnapshot.rows.first?.content == "msg 3")
        #expect(h.coordinator.latestSnapshot.hasEarlierRows)

        let anchor = await h.coordinator.loadEarlier(isAtBottom: false)
        #expect(anchor != nil)
        let snapshot = h.coordinator.latestSnapshot
        #expect(snapshot.rows.count == 6)
        #expect(snapshot.rows.first?.content == "msg 0")
        #expect(snapshot.rows.map(\.content) == (0..<6).map { "msg \($0)" })
    }

    // MARK: - Stale result rejection

    @Test("切换会话后，旧会话结果不会覆盖新会话")
    func staleConversationResultsRejected() async {
        let h = Harness()
        for i in 0..<4 {
            h.makeMessage(conversationID: h.conversationA, content: "a \(i)", at: 100 + Double(i), idSuffix: i)
            h.makeMessage(conversationID: h.conversationB, content: "b \(i)", at: 100 + Double(i), idSuffix: 10 + i)
        }
        await h.coordinator.activate(conversationID: h.conversationA)
        await h.coordinator.activate(conversationID: h.conversationB)

        let snapshot = h.coordinator.latestSnapshot
        #expect(snapshot.conversationID == h.conversationB)
        #expect(snapshot.rows.allSatisfy { $0.content.hasPrefix("b ") })
    }

    // MARK: - Notification scoping

    @Test("其它会话的消息通知不触发刷新，本会话的触发")
    func notificationScopedToSelectedConversation() async {
        let h = Harness()
        h.makeMessage(conversationID: h.conversationA, content: "old", at: 100, idSuffix: 1)
        await h.coordinator.activate(conversationID: h.conversationA)
        #expect(h.coordinator.latestSnapshot.rows.count == 1)

        // 插入到 B 并广播 B 的变更 → 不应影响 A 的快照。
        h.makeMessage(conversationID: h.conversationB, content: "b-only", at: 200, idSuffix: 2)
        NotificationCenter.default.post(
            name: .lumiMessagesDidChange,
            object: nil,
            userInfo: [LumiNotificationUserInfoKey.conversationID: h.conversationB]
        )
        try? await Task.sleep(nanoseconds: 40_000_000)
        #expect(h.coordinator.latestSnapshot.rows.count == 1)

        // 插入到 A 并广播 A 的变更 → 快照更新。
        h.makeMessage(conversationID: h.conversationA, content: "new", at: 300, idSuffix: 3)
        NotificationCenter.default.post(
            name: .lumiMessagesDidChange,
            object: nil,
            userInfo: [LumiNotificationUserInfoKey.conversationID: h.conversationA]
        )
        try? await Task.sleep(nanoseconds: 40_000_000)
        #expect(h.coordinator.latestSnapshot.rows.count == 2)
    }

    // MARK: - Live tail updates

    @Test("流式行出现：V2 快照尾部附加流式行")
    func liveTailAppears() async {
        let h = Harness()
        h.makeMessage(conversationID: h.conversationA, content: "done", at: 100, idSuffix: 1)
        await h.coordinator.activate(conversationID: h.conversationA)

        await h.streaming.startStreaming(conversationID: h.conversationA)
        await h.streaming.appendContent("正在生成", conversationID: h.conversationA)
        // 等待节流窗口（16ms）+ runloop 排空。
        try? await Task.sleep(nanoseconds: 60_000_000)

        let snapshot = h.coordinator.latestSnapshot
        #expect(snapshot.streamingRow != nil)
        #expect(snapshot.streamingRow?.kind == .streaming)
        #expect(snapshot.streamingRow?.content == "正在生成")
        #expect(snapshot.isLive)
    }

    @Test("流式结束：流式行从快照移除")
    func liveTailDisappears() async {
        let h = Harness()
        h.makeMessage(conversationID: h.conversationA, content: "done", at: 100, idSuffix: 1)
        await h.coordinator.activate(conversationID: h.conversationA)

        await h.streaming.startStreaming(conversationID: h.conversationA)
        await h.streaming.endStreaming(conversationID: h.conversationA)
        try? await Task.sleep(nanoseconds: 60_000_000)

        let snapshot = h.coordinator.latestSnapshot
        #expect(snapshot.streamingRow == nil)
        #expect(!snapshot.isLive)
    }

    // MARK: - V1 (brief) projection through the coordinator

    @Test("brief 模式：每个 turn 一条结论行 + 尾部 status 行")
    func briefProjectionThroughCoordinator() async throws {
        let h = Harness(verbosity: .brief)
        let fixture = try FixtureLoader.briefTurns()
        let records = fixture.turns.map {
            FixtureLoader.turnRecord(from: $0, conversationID: fixture.conversationID)
        }
        h.turns.seed(records, conversationID: fixture.conversationID)
        h.messages.seed(fixture.messages, conversationID: fixture.conversationID)

        await h.coordinator.activate(conversationID: fixture.conversationID)

        let snapshot = h.coordinator.latestSnapshot
        // 4 个终态 turn（completed/failed/suspended/cancelled）→ 4 结论 + 1 status。
        #expect(snapshot.rows.count == 5)
        #expect(snapshot.rows.filter { $0.kind == .conclusion }.count == 4)
        #expect(snapshot.rows.last?.kind == .status)
        #expect(snapshot.streamingRow == nil)
    }

    // MARK: - Refresh coalescing

    @Test("refresh 合并：突发通知折叠为一次有效刷新")
    func refreshCoalescing() async {
        let h = Harness()
        h.makeMessage(conversationID: h.conversationA, content: "first", at: 100, idSuffix: 1)
        await h.coordinator.activate(conversationID: h.conversationA)

        // 突发 5 个通知 → 门控折叠，快照最终收敛到最新状态。
        for i in 0..<5 {
            NotificationCenter.default.post(
                name: .lumiMessagesDidChange,
                object: nil,
                userInfo: [LumiNotificationUserInfoKey.conversationID: h.conversationA]
            )
            _ = i
        }
        await Task.yield()
        #expect(h.coordinator.latestSnapshot.rows.count == 1)
    }
}
