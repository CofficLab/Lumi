import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageManager

@MainActor
@Suite("消息截断：持久化")
struct MessageTruncationPersistenceTests {
    private func makeStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageTruncation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    private func makeManager(store: MessageStore) -> MessageManager {
        MessageManager(store: store, dataDirectory: URL(fileURLWithPath: NSTemporaryDirectory()))
    }

    /// 六条消息：两条同属一个 turn 的旧消息，目标用户消息，以及其后的回复、工具结果和通知。
    private func makeTimeline(conversationID: UUID, base: Date) -> [Message] {
        [
            Message(conversationID: conversationID, role: .user, content: "old question", createdAt: base),
            Message(conversationID: conversationID, role: .assistant, content: "old answer", createdAt: base.addingTimeInterval(1)),
            Message(conversationID: conversationID, role: .user, content: "typo question", createdAt: base.addingTimeInterval(2)),
            Message(conversationID: conversationID, role: .assistant, content: "typo answer", createdAt: base.addingTimeInterval(3)),
            Message(
                conversationID: conversationID,
                role: .tool,
                content: "tool result",
                createdAt: base.addingTimeInterval(4),
                toolCallID: "call-1"
            ),
            Message(
                conversationID: conversationID,
                role: .user,
                content: "background notification",
                createdAt: base.addingTimeInterval(5),
                metadata: ["lumi.backgroundNotification": "true"]
            ),
        ]
    }

    @Test("截断只保留前缀，磁盘与读路径一致")
    func truncationKeepsPrefixOnDiskAndReads() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let timeline = makeTimeline(conversationID: conversationID, base: Date(timeIntervalSince1970: 1_700_000_000))
        timeline.forEach { manager.insertMessage($0, to: conversationID) }
        manager.flushPendingWrites()
        #expect(store.messageCount(conversationId: conversationID) == 6)

        manager.deleteMessages(from: timeline[2].id, in: conversationID)

        let expectedIDs = [timeline[0].id, timeline[1].id]
        #expect(store.fetchMessages(conversationId: conversationID).map(\.id) == expectedIDs)
        #expect(manager.messages(for: conversationID).map(\.id) == expectedIDs)
        #expect(await manager.messagesForLLM(in: conversationID).map(\.id) == expectedIDs)
        #expect(manager.message(id: timeline[2].id, in: conversationID) == nil)
        #expect(manager.lastMessage(in: conversationID)?.id == timeline[1].id)
        #expect(store.messageCount(conversationId: conversationID) == 2)
    }

    @Test("截断只发布一个 truncated 事件")
    func truncationPublishesOneEvent() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let timeline = makeTimeline(conversationID: conversationID, base: Date(timeIntervalSince1970: 1_700_000_000))
        timeline.forEach { manager.insertMessage($0, to: conversationID) }
        manager.flushPendingWrites()
        var changes: [MessageChange] = []
        // 落盘完成的通知经 Task 回到主线程，可能晚于注册观察者才送达，与截断无关。
        let handle = manager.addMessageChangeObserver { change in
            guard case .persisted = change else {
                changes.append(change)
                return
            }
        }
        defer { handle.cancel() }

        manager.deleteMessages(from: timeline[2].id, in: conversationID)

        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(changes.count == 1)
        guard case let .truncated(messageID, changedConversationID) = changes.first else {
            Issue.record("expected a single .truncated change, got \(changes)")
            return
        }
        #expect(messageID == timeline[2].id)
        #expect(changedConversationID == conversationID)
    }

    @Test("目标不存在时磁盘与事件都不变")
    func unknownTargetIsNoOp() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let timeline = makeTimeline(conversationID: conversationID, base: Date(timeIntervalSince1970: 1_700_000_000))
        timeline.forEach { manager.insertMessage($0, to: conversationID) }
        manager.flushPendingWrites()
        var changes: [MessageChange] = []
        manager.addMessageChangeObserver { changes.append($0) }

        manager.deleteMessages(from: UUID(), in: conversationID)
        manager.deleteMessages(from: timeline[2].id, in: UUID())

        #expect(store.fetchMessages(conversationId: conversationID).map(\.id) == timeline.map(\.id))
        #expect(changes.isEmpty)
    }

    /// 时间戳相同的消息按 id 排序，目标之前的同时间消息保留。
    @Test("同一时间的消息按 id 排序，目标之前的同时间消息保留")
    func sameTimestampMessagesBeforeTargetSurvive() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let ordered = [1, 3, 5, 7, 9].map { index in
            Message(
                id: Self.fixedID(index),
                conversationID: conversationID,
                role: .user,
                content: "\(index)",
                createdAt: createdAt
            )
        }
        // 乱序插入，确认截断依赖的是时间线顺序而不是插入顺序。
        for message in [ordered[4], ordered[0], ordered[3], ordered[1], ordered[2]] {
            manager.insertMessage(message, to: conversationID)
        }
        manager.flushPendingWrites()

        manager.deleteMessages(from: ordered[2].id, in: conversationID)

        #expect(store.fetchMessages(conversationId: conversationID).map(\.id) == [ordered[0].id, ordered[1].id])
        #expect(manager.messages(for: conversationID).map(\.id) == [ordered[0].id, ordered[1].id])
    }

    @Test("截断不影响其他会话的消息")
    func otherConversationsAreUntouched() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let otherConversationID = UUID()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let timeline = makeTimeline(conversationID: conversationID, base: base)
        let other = (0..<3).map { index in
            Message(
                conversationID: otherConversationID,
                role: .user,
                content: "other \(index)",
                createdAt: base.addingTimeInterval(Double(index))
            )
        }
        timeline.forEach { manager.insertMessage($0, to: conversationID) }
        other.forEach { manager.insertMessage($0, to: otherConversationID) }
        manager.flushPendingWrites()

        manager.deleteMessages(from: timeline[0].id, in: conversationID)

        #expect(store.fetchMessages(conversationId: conversationID).isEmpty)
        #expect(manager.messages(for: conversationID).isEmpty)
        #expect(store.fetchMessages(conversationId: otherConversationID).map(\.id) == other.map(\.id))
    }

    @Test("存储层按显式 id 列表删除，且只作用于指定会话")
    func storeDeletesByExplicitIDs() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()
        let otherConversationID = UUID()
        let first = Message(conversationID: conversationID, role: .user, content: "first")
        let second = Message(conversationID: conversationID, role: .user, content: "second")
        let third = Message(conversationID: conversationID, role: .user, content: "third")
        let other = Message(conversationID: otherConversationID, role: .user, content: "other")
        for message in [first, second, third, other] { try store.insertMessage(message) }

        #expect(store.deleteMessages(ids: [second.id, third.id, other.id], conversationId: conversationID))

        #expect(store.fetchMessages(conversationId: conversationID).map(\.id) == [first.id])
        #expect(store.fetchMessages(conversationId: otherConversationID).map(\.id) == [other.id])
        #expect(store.deleteMessages(ids: [], conversationId: conversationID))
        #expect(store.fetchMessages(conversationId: conversationID).count == 1)
    }

    @Test("存储层时间线按 createdAt 再按 id 排序")
    func storeTimelineIsOrdered() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()
        let sameTime = Date(timeIntervalSince1970: 1_700_000_000)
        func make(_ index: Int, conversationID: UUID = conversationID, createdAt: Date = sameTime) -> Message {
            Message(
                id: Self.fixedID(index),
                conversationID: conversationID,
                role: .user,
                content: "\(index)",
                createdAt: createdAt
            )
        }
        let earlier = make(5, createdAt: sameTime.addingTimeInterval(-1))
        let tied = [make(3), make(1), make(2)]
        let later = make(0, createdAt: sameTime.addingTimeInterval(1))
        let other = make(9, conversationID: UUID())
        for message in [later, other] + tied + [earlier] { try store.insertMessage(message) }

        let timeline = store.fetchMessageTimeline(conversationId: conversationID)

        #expect(timeline.map(\.id) == [5, 1, 2, 3, 0].map(Self.fixedID))
        #expect(timeline.map(\.createdAt) == timeline.map(\.createdAt).sorted())
    }

    private static func fixedID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
    }
}
