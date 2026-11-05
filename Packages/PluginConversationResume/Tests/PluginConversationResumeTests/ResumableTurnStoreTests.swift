import Foundation
import Testing
@testable import PluginConversationResume

struct ResumableTurnStoreTests {
    // MARK: - 辅助

    private func makeStore() -> (store: ResumableTurnStore, url: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-store-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("turns.json")
        return (ResumableTurnStore(fileURL: url), url)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // MARK: - 读写

    @Test("回合开始后写入运行中记录")
    func marksRunning() async {
        let (store, url) = makeStore()
        defer { cleanup(url) }
        let conversationID = UUID()
        let turnID = UUID()

        await store.markRunning(conversationID: conversationID, turnID: turnID)

        let record = await store.record(for: conversationID)
        #expect(record?.turnID == turnID)
        #expect(record?.outcome == .interrupted)
        #expect(record?.isResumable == true)
    }

    @Test("回合结束后记录终态，不再可继续")
    func marksFinished() async {
        let (store, url) = makeStore()
        defer { cleanup(url) }
        let conversationID = UUID()
        let turnID = UUID()

        await store.markRunning(conversationID: conversationID, turnID: turnID)
        await store.markFinished(
            conversationID: conversationID,
            turnID: turnID,
            outcome: .completed
        )

        let record = await store.record(for: conversationID)
        #expect(record?.outcome == .completed)
        #expect(record?.isResumable == false)
    }

    @Test("用户取消的回合不会被标记为可继续")
    func cancelledIsNotResumable() async {
        let (store, url) = makeStore()
        defer { cleanup(url) }
        let conversationID = UUID()
        let turnID = UUID()

        await store.markRunning(conversationID: conversationID, turnID: turnID)
        await store.markFinished(
            conversationID: conversationID,
            turnID: turnID,
            outcome: .cancelled
        )

        let record = await store.record(for: conversationID)
        #expect(record?.isResumable == false)
    }

    @Test("终态记录保留回合开始时间")
    func finishedKeepsStartedAt() async {
        let (store, url) = makeStore()
        defer { cleanup(url) }
        let conversationID = UUID()
        let turnID = UUID()
        let startedAt = Date(timeIntervalSince1970: 5_000)

        await store.markRunning(conversationID: conversationID, turnID: turnID, startedAt: startedAt)
        await store.markFinished(
            conversationID: conversationID,
            turnID: turnID,
            outcome: .completed,
            recordedAt: Date(timeIntervalSince1970: 6_000)
        )

        let record = await store.record(for: conversationID)
        #expect(record?.startedAt == startedAt)
    }

    // MARK: - 崩溃恢复（核心）

    @Test("崩溃后重新打开存储仍能读出中断状态")
    func survivesProcessRestart() async {
        let (store, url) = makeStore()
        let conversationID = UUID()
        let turnID = UUID()

        await store.markRunning(conversationID: conversationID, turnID: turnID)

        // 模拟进程重启：新建 store 实例指向同一文件。
        let reopened = ResumableTurnStore(fileURL: url)
        let record = await reopened.record(for: conversationID)

        #expect(record?.turnID == turnID)
        #expect(record?.outcome == .interrupted)
        #expect(record?.isResumable == true)
    }

    @Test("崩溃后正常收尾的回合不会复活")
    func finishedTurnDoesNotResurrect() async {
        let (store, url) = makeStore()
        let conversationID = UUID()
        let turnID = UUID()

        await store.markRunning(conversationID: conversationID, turnID: turnID)
        await store.markFinished(
            conversationID: conversationID,
            turnID: turnID,
            outcome: .completed
        )

        let reopened = ResumableTurnStore(fileURL: url)
        let record = await reopened.record(for: conversationID)

        #expect(record?.outcome == .completed)
        #expect(record?.isResumable == false)
    }

    @Test("存储文件损坏时退回空记录而不是崩溃")
    func corruptedFileFallsBackToEmpty() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-store-corrupt-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("turns.json")
        try? Data("not json at all".utf8).write(to: url)
        defer { cleanup(url) }

        let store = ResumableTurnStore(fileURL: url)
        let records = await store.allRecords()

        #expect(records.isEmpty)
    }

    @Test("空文件不影响启动")
    func emptyFileIsHarmless() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-store-empty-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("turns.json")
        try? Data().write(to: url)
        defer { cleanup(url) }

        let store = ResumableTurnStore(fileURL: url)
        let records = await store.allRecords()

        #expect(records.isEmpty)
    }

    // MARK: - 工具调用追踪

    @Test("记录最后一个工具调用 ID")
    func tracksLastToolCallID() async {
        let (store, url) = makeStore()
        defer { cleanup(url) }
        let conversationID = UUID()
        let turnID = UUID()

        await store.markRunning(conversationID: conversationID, turnID: turnID)
        await store.markToolCall(
            conversationID: conversationID,
            turnID: turnID,
            toolCallID: "call_42"
        )

        let record = await store.record(for: conversationID)
        #expect(record?.lastToolCallID == "call_42")
    }

    @Test("工具调用 ID 跨回合更新不被串写")
    func ignoresToolCallFromOtherTurn() async {
        let (store, url) = makeStore()
        defer { cleanup(url) }
        let conversationID = UUID()
        let turnID = UUID()

        await store.markRunning(conversationID: conversationID, turnID: turnID)
        await store.markToolCall(
            conversationID: conversationID,
            turnID: UUID(),
            toolCallID: "other_turn"
        )

        let record = await store.record(for: conversationID)
        #expect(record?.lastToolCallID == nil)
    }

    // MARK: - 清理

    @Test("清除会话记录后不再可继续")
    func clearRemovesRecord() async {
        let (store, url) = makeStore()
        defer { cleanup(url) }
        let conversationID = UUID()

        await store.markRunning(conversationID: conversationID, turnID: UUID())
        await store.clear(conversationID: conversationID)

        let record = await store.record(for: conversationID)
        #expect(record == nil)
    }

    @Test("每个会话只保留最新一条记录")
    func keepsOnlyLatestPerConversation() async {
        let (store, url) = makeStore()
        defer { cleanup(url) }
        let conversationID = UUID()

        await store.markRunning(conversationID: conversationID, turnID: UUID())
        await store.markFinished(
            conversationID: conversationID,
            turnID: UUID(),
            outcome: .completed
        )
        await store.markRunning(conversationID: conversationID, turnID: UUID())

        let records = await store.allRecords()
        #expect(records.count == 1)
        #expect(records[conversationID]?.isResumable == true)
    }
}
