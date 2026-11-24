import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// 编辑用户消息会在发送后立刻截断时间线，此时尾部消息往往还在后台落盘队列里。
@MainActor
@Suite("消息截断：write-behind")
struct MessageTruncationWriteBehindTests {
    private func makeStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageTruncationWB-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    private func makeManager(store: MessageStore) -> MessageManager {
        MessageManager(store: store, dataDirectory: URL(fileURLWithPath: NSTemporaryDirectory()))
    }

    private func makeTimeline(conversationID: UUID, base: Date) -> [Message] {
        (0..<4).map { offset in
            Message(
                conversationID: conversationID,
                role: offset % 2 == 0 ? .user : .assistant,
                content: "message \(offset)",
                createdAt: base.addingTimeInterval(Double(offset))
            )
        }
    }

    @Test("插入后立即截断，落盘队列排空后已删消息不会复活")
    func truncateRightAfterInsertDoesNotResurrectTail() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let timeline = makeTimeline(conversationID: conversationID, base: Date(timeIntervalSince1970: 1_700_000_000))
        timeline.forEach { manager.insertMessage($0, to: conversationID) }
        let removedIDs = Set(timeline.dropFirst().map(\.id))

        manager.deleteMessages(from: timeline[1].id, in: conversationID)
        manager.flushPendingWrites()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(store.fetchMessages(conversationId: conversationID).map(\.id) == [timeline[0].id])
        #expect(manager.messages(for: conversationID).map(\.id) == [timeline[0].id])
        #expect(Set(manager.pending.snapshot(for: conversationID).map(\.id)).isDisjoint(with: removedIDs))
        #expect(await manager.messagesForLLM(in: conversationID).map(\.id) == [timeline[0].id])
    }

    @Test("目标只在 pending 里时同样可截断")
    func targetStillInPendingIsTruncated() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let timeline = makeTimeline(conversationID: conversationID, base: Date(timeIntervalSince1970: 1_700_000_000))
        manager.insertMessage(timeline[0], to: conversationID)
        manager.flushPendingWrites()
        manager.insertMessage(timeline[1], to: conversationID)
        manager.insertMessage(timeline[2], to: conversationID)
        var changes: [MessageChange] = []
        let handle = manager.addMessageChangeObserver { change in
            guard case .persisted = change else {
                changes.append(change)
                return
            }
        }
        defer { handle.cancel() }

        manager.deleteMessages(from: timeline[1].id, in: conversationID)
        manager.flushPendingWrites()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(store.fetchMessages(conversationId: conversationID).map(\.id) == [timeline[0].id])
        #expect(manager.pending.snapshot(for: conversationID).isEmpty)
        #expect(manager.message(id: timeline[1].id, in: conversationID) == nil)
        #expect(manager.message(id: timeline[2].id, in: conversationID) == nil)
        guard case .truncated = changes.first, changes.count == 1 else {
            Issue.record("expected a single .truncated change, got \(changes)")
            return
        }
    }

    @Test("截断后插入新消息，新消息排在保留的前缀之后")
    func insertAfterTruncationLandsAfterPrefix() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let timeline = makeTimeline(conversationID: conversationID, base: base)
        timeline.forEach { manager.insertMessage($0, to: conversationID) }
        manager.flushPendingWrites()

        manager.deleteMessages(from: timeline[1].id, in: conversationID)
        let edited = Message(
            conversationID: conversationID,
            role: .user,
            content: "edited",
            createdAt: base.addingTimeInterval(10)
        )
        manager.insertMessage(edited, to: conversationID)
        manager.flushPendingWrites()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(store.fetchMessages(conversationId: conversationID).map(\.id) == [timeline[0].id, edited.id])
        #expect(await manager.messagesSnapshot(in: conversationID).map(\.id) == [timeline[0].id, edited.id])
        #expect(manager.messagePage(for: conversationID, limit: 10, beforeMessageID: nil).map(\.id) == [timeline[0].id, edited.id])
    }

    @Test("截断同时移除被删消息的工具结果补丁")
    func truncationDropsToolResultPatchesOfRemovedMessages() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let user = Message(conversationID: conversationID, role: .user, content: "q", createdAt: base)
        let call = MessageToolCall(id: "call-1", name: "read", arguments: "{}")
        let assistant = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "a",
            createdAt: base.addingTimeInterval(1),
            toolCalls: [call]
        )
        manager.insertMessage(user, to: conversationID)
        manager.insertMessage(assistant, to: conversationID)
        manager.flushPendingWrites()
        manager.updateToolCallResult(
            MessageToolResult(content: "ok", duration: nil, isError: false, imageAttachments: []),
            toolCallID: "call-1",
            assistantMessageID: assistant.id,
            in: conversationID
        )
        #expect(!manager.pending.toolResultPatches(for: conversationID).isEmpty)

        manager.deleteMessages(from: user.id, in: conversationID)

        #expect(manager.pending.toolResultPatches(for: conversationID).isEmpty)
        #expect(store.fetchMessages(conversationId: conversationID).isEmpty)
    }
}
