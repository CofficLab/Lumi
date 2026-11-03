import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

/// 「对话统计」所需的存储层查询与清理。
///
/// 这组用例守住的语义：
/// 1. 每日计数按自然日分桶，且受项目与「是否含子会话」约束；
/// 2. 「创建于 cutoff 之前」按 `createdAt` 判定，而不是 `updatedAt`；
/// 3. 清理父会话时连带清掉其子 Agent 会话。
@Suite("ConversationStore 统计与批量清理")
@MainActor
struct ConversationStoreStatsTests {
    private func makeStore() throws -> (store: ConversationStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-conversation-stats-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try ConversationStore(databaseRootURL: directory), directory)
    }

    @Test("每日计数按自然日分桶")
    func countsPerCalendarDay() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        try await store.createConversation(
            id: UUID(), title: "t1", createdAt: today.addingTimeInterval(3_600)
        )
        try await store.createConversation(
            id: UUID(), title: "t2", createdAt: today.addingTimeInterval(7_200)
        )
        try await store.createConversation(
            id: UUID(), title: "y1", createdAt: yesterday.addingTimeInterval(3_600)
        )

        let series = await store.fetchDailyCountSeries(days: 2, includingChildConversations: false)
        #expect(series.points.count == 2)
        #expect(series.points[0].count == 1, "昨天")
        #expect(series.points[1].count == 2, "今天")
        #expect(series.totalCount == 3)
        #expect(series.peakCount == 2)
    }

    @Test("项目作用域只统计该项目")
    func scopesToProject() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        try await store.createConversation(
            id: UUID(), title: "mine", projectPath: "/tmp/project-a"
        )
        try await store.createConversation(
            id: UUID(), title: "other", projectPath: "/tmp/project-b"
        )

        let series = await store.fetchDailyCountSeries(
            days: 2,
            projectPath: "/tmp/project-a",
            includingChildConversations: false
        )
        #expect(series.totalCount == 1)
    }

    @Test("排除子 Agent 会话时只数顶层对话")
    func excludesChildConversations() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let parent = UUID()
        try await store.createConversation(id: parent, title: "parent")
        try await store.createConversation(
            id: UUID(), title: "child", parentConversationID: parent
        )

        let topLevelOnly = await store.fetchDailyCountSeries(
            days: 2,
            includingChildConversations: false
        )
        #expect(topLevelOnly.totalCount == 1)

        let includingChildren = await store.fetchDailyCountSeries(
            days: 2,
            includingChildConversations: true
        )
        #expect(includingChildren.totalCount == 2)
    }

    @Test("「创建于 cutoff 之前」按 createdAt 判定")
    func selectsByCreatedAt() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let now = Date()
        let cutoff = now.addingTimeInterval(-86_400)

        let old = UUID()
        let fresh = UUID()
        try await store.createConversation(
            id: old, title: "old", createdAt: now.addingTimeInterval(-86_400 * 10)
        )
        try await store.createConversation(
            id: fresh, title: "fresh", createdAt: now
        )

        let ids = await store.conversationIDs(
            createdBefore: cutoff,
            includingChildConversations: false
        )
        #expect(ids == [old])

        let count = await store.conversationCount(
            createdBefore: cutoff,
            includingChildConversations: false
        )
        #expect(count == 1)
    }

    @Test("清理父会话时连带清掉子 Agent 会话")
    func deletesDescendantsAlongsideParent() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let now = Date()
        let parent = UUID()
        let child = UUID()
        let grandchild = UUID()
        let survivor = UUID()

        try await store.createConversation(
            id: parent, title: "parent", createdAt: now.addingTimeInterval(-86_400 * 10)
        )
        try await store.createConversation(
            id: child, title: "child",
            createdAt: now.addingTimeInterval(-86_400 * 9),
            parentConversationID: parent
        )
        try await store.createConversation(
            id: grandchild, title: "grandchild",
            createdAt: now.addingTimeInterval(-86_400 * 8),
            parentConversationID: child
        )
        try await store.createConversation(
            id: survivor, title: "survivor", createdAt: now
        )

        // 只按顶层会话命中父会话。
        let ids = await store.conversationIDs(
            createdBefore: now.addingTimeInterval(-86_400),
            includingChildConversations: false
        )
        #expect(ids == [parent])

        // 级联集合应包含父、子、孙。
        let cascade = await store.conversationIDsToDelete(id: parent)
        #expect(Set(cascade) == Set([parent, child, grandchild]))

        // 批量删除后，幸存者仍在。
        _ = await store.deleteConversations(ids: cascade)
        let remaining = await store.conversationIDs(
            createdBefore: Date().addingTimeInterval(86_400 * 365),
            includingChildConversations: true
        )
        #expect(remaining == [survivor])
    }
}
