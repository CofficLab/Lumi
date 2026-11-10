import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

/// 统计账本：删除会话后统计信息不受影响。
///
/// 这组用例守住的核心语义：
/// 1. 账本独立于会话表存在——删掉会话，历史计数不回落；
/// 2. 回填只在首次建立时做一次，且取「账本值」与「表值」的较大者；
/// 3. 项目与「是否含子会话」两个维度的过滤仍然生效。
@Suite("ConversationStore 统计账本")
@MainActor
struct ConversationCountLedgerTests {
    private func makeStore() throws -> (store: ConversationStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-conversation-ledger-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try ConversationStore(databaseRootURL: directory), directory)
    }

    @Test("删除会话后每日计数保持不变")
    func countsSurviveDeletion() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))

        let oldID = UUID()
        try await store.createConversation(
            id: oldID,
            title: "old",
            createdAt: yesterday.addingTimeInterval(3_600)
        )

        let before = await store.fetchDailyCountSeries(days: 2, includingChildConversations: false)
        #expect(before.points.map(\.count) == [1, 0], "删除前：昨天 1 条，今天 0 条")

        // 删除这条会话。
        let deleted = await store.deleteConversations(ids: [oldID])
        #expect(deleted)

        let after = await store.fetchDailyCountSeries(days: 2, includingChildConversations: false)
        #expect(after.points.map(\.count) == [1, 0], "删除会话后统计不应回落")
        #expect(after.totalCount == before.totalCount)
    }

    @Test("批量清理旧对话后统计保持不变")
    func countsSurviveBulkCleanup() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tenDaysAgo = try #require(calendar.date(byAdding: .day, value: -10, to: today))

        let oldID = UUID()
        try await store.createConversation(id: oldID, title: "old", createdAt: tenDaysAgo)
        try await store.createConversation(id: UUID(), title: "fresh", createdAt: today)

        let before = await store.fetchDailyCountSeries(days: 30, includingChildConversations: false)
        let beforeTotal = before.totalCount
        #expect(beforeTotal == 2)

        // 清理 7 天前的对话。
        let cutoff = try #require(calendar.date(byAdding: .day, value: -7, to: today))
        let ids = await store.conversationIDs(createdBefore: cutoff, includingChildConversations: false)
        #expect(ids == [oldID])
        _ = await store.deleteConversations(ids: ids)

        let after = await store.fetchDailyCountSeries(days: 30, includingChildConversations: false)
        #expect(after.totalCount == beforeTotal, "清理旧对话后总数不应减少")
    }

    @Test("重启后账本从磁盘恢复，不重复回填")
    func ledgerSurvivesRestart() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let id = UUID()
        try await store.createConversation(id: id, title: "one", createdAt: today)

        // 用同一目录重建 store，模拟应用重启。
        let reopened = try ConversationStore(databaseRootURL: directory)

        let series = await reopened.fetchDailyCountSeries(days: 1, includingChildConversations: false)
        #expect(series.totalCount == 1, "重启后计数应从账本恢复，而不是重新回填成 2")

        // 再建一个会话后重启，计数应是 2 而不是 3（没有重复回填）。
        try await reopened.createConversation(id: UUID(), title: "two", createdAt: today)
        let reopenedAgain = try ConversationStore(databaseRootURL: directory)
        let series2 = await reopenedAgain.fetchDailyCountSeries(days: 1, includingChildConversations: false)
        #expect(series2.totalCount == 2)
    }

    @Test("账本按项目维度隔离")
    func scopesToProject() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        try await store.createConversation(
            id: UUID(), title: "mine", createdAt: today, projectPath: "/tmp/project-a"
        )
        try await store.createConversation(
            id: UUID(), title: "other", createdAt: today, projectPath: "/tmp/project-b"
        )

        let scoped = await store.fetchDailyCountSeries(
            days: 1,
            projectPath: "/tmp/project-a",
            includingChildConversations: false
        )
        #expect(scoped.totalCount == 1)
    }

    @Test("子 Agent 会话不计入顶层统计")
    func excludesChildConversations() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let parent = UUID()
        try await store.createConversation(id: parent, title: "parent")
        try await store.createConversation(
            id: UUID(), title: "child", parentConversationID: parent
        )

        let topLevelOnly = await store.fetchDailyCountSeries(days: 1, includingChildConversations: false)
        #expect(topLevelOnly.totalCount == 1)

        let includingChildren = await store.fetchDailyCountSeries(days: 1, includingChildConversations: true)
        #expect(includingChildren.totalCount == 2)
    }
}
