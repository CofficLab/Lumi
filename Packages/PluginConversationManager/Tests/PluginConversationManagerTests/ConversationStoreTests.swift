import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

/// ConversationStore（SwiftData 持久化）单元测试。
@Suite("ConversationStore")
struct ConversationStoreTests {
    /// 每个测试独立的临时数据库目录。
    private func makeStore() throws -> (ConversationStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-conversation-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = try ConversationStore(databaseRootURL: dir)
        return (store, dir)
    }

    @Test("创建会话后可分页查询")
    func createAndFetch() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try await store.createConversation(
            id: UUID(),
            title: "测试对话",
            verbosity: .brief,
            providerID: "openai",
            modelName: "gpt-4",
            projectPath: "/tmp/project-a"
        )
        let page = await store.fetchConversationPage(limit: 40)
        #expect(page.count == 1)
        #expect(page.first?.title == "测试对话")
        #expect(page.first?.verbosity == .brief)
        #expect(page.first?.projectPath == "/tmp/project-a")
        #expect(page.first?.providerID == "openai")
    }

    @Test("更新会话详细程度后可持久化")
    func updateVerbosity() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let id = UUID()
        try await store.createConversation(id: id, title: "详细程度测试", verbosity: .standard)

        let updated = await store.updateConversationPreferences(id: id, verbosity: .brief)
        #expect(updated)
        #expect(await store.fetchConversation(id: id)?.verbosity == .brief)
    }

    @Test("ConversationManager 等待详细程度写入完成")
    @MainActor
    func managerSetVerbosityAndWaitPersists() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let id = UUID()
        try await store.createConversation(id: id, title: "管理器测试", verbosity: .standard)
        let manager = ConversationManager(store: store, dataDirectory: dir)
        manager.conversations = [ConversationSummary(id: id, verbosity: .standard)]

        await manager.setVerbosityAndWait(.brief, for: id)

        #expect(await store.fetchConversation(id: id)?.verbosity == .brief)
    }

    @Test("迁移导入按 id 去重（幂等）")
    func importSummariesIsIdempotent() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let summary = ConversationSummary(
            id: UUID(),
            title: "历史会话",
            preview: "v4 迁移",
            verbosity: .detailed,
            providerID: "deepseek",
            projectPath: "/tmp/legacy"
        )

        let first = try await store.importSummaries([summary])
        #expect(first == 1)

        // 重复导入同一 id：跳过，不产生重复数据。
        let second = try await store.importSummaries([summary])
        #expect(second == 0)

        let count = await store.conversationCount(projectPath: nil, includingChildConversations: true)
        #expect(count == 1)
    }

    @Test("更新标题与删除")
    func updateAndDelete() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let id = UUID()
        try await store.createConversation(id: id, title: "原始标题")

        let updated = await store.updateTitle(id: id, title: "新标题")
        #expect(updated)

        let fetched = await store.fetchConversation(id: id)
        #expect(fetched?.title == "新标题")

        let deleted = await store.deleteConversations(ids: [id])
        #expect(deleted)
        #expect(await store.fetchConversation(id: id) == nil)
    }

    @Test("子代理对话纳入级联删除范围")
    func cascadeDeleteIncludesChildren() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let rootID = UUID()
        let childID = UUID()
        try await store.createConversation(id: rootID, title: "根对话")
        try await store.createConversation(id: childID, title: "子代理对话", parentConversationID: rootID)

        let ids = await store.conversationIDsToDelete(id: rootID)
        #expect(ids.count == 2)
        #expect(Set(ids) == [rootID, childID])
    }

    @Test("分页、项目过滤、会话统计和每日统计")
    func projectPagesCountsAndDailySeries() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let twoDaysAgo = try #require(calendar.date(byAdding: .day, value: -2, to: today))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let oldID = UUID()
        let recentID = UUID()
        let otherProjectID = UUID()
        let childID = UUID()
        try await store.createConversation(id: oldID, title: "old", createdAt: twoDaysAgo, projectPath: "/project/a")
        try await store.createConversation(id: recentID, title: "recent", createdAt: today, projectPath: "/project/a")
        try await store.createConversation(id: otherProjectID, title: "other", createdAt: yesterday, projectPath: "/project/b")
        try await store.createConversation(
            id: childID,
            title: "child",
            createdAt: yesterday,
            projectPath: "/project/a",
            parentConversationID: recentID
        )

        let firstPage = await store.fetchConversationPage(limit: 1, projectPath: "/project/a")
        #expect(firstPage.map(\.id) == [recentID])
        let secondPage = await store.fetchConversationPage(
            limit: 2,
            beforeUpdatedAt: firstPage[0].createdAt,
            beforeID: recentID,
            projectPath: "/project/a"
        )
        #expect(secondPage.map(\.id) == [oldID])
        let withChildren = await store.fetchConversationPage(
            limit: 10,
            includingChildConversations: true,
            projectPath: "/project/a"
        )
        #expect(Set(withChildren.map(\.id)) == [oldID, recentID, childID])
        #expect(await store.conversationCount(includingChildConversations: false) == 3)
        #expect(await store.conversationCount(projectPath: "/project/a", includingChildConversations: false) == 2)
        #expect(await store.conversationCount(projectPath: "/project/a", includingChildConversations: true) == 3)
        #expect(await store.conversationProjectCount() == 2)

        let series = await store.fetchDailyCountSeries(days: 3, endingAt: today)
        #expect(series.points.map(\.count) == [1, 2, 1])
        #expect(series.peakCount == 2)
        #expect(await store.fetchDailyCountSeries(days: 0, endingAt: today).points.isEmpty)
    }

    @Test("会话字段更新和批量迁移路径")
    func updatesConversationFieldsAndProjectPaths() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let id = UUID()
        let childID = UUID()
        try await store.createConversation(id: id, title: " Original ", projectPath: "/before")
        try await store.createConversation(id: childID, title: "child", projectPath: "/before", parentConversationID: id)
        #expect(await store.updateTitle(id: id, title: "  Renamed  "))
        #expect(await store.updatePreview(id: id, preview: "latest answer"))
        let lastMessageAt = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(await store.updateLastMessageAt(id: id, messageDate: lastMessageAt))
        #expect(await store.updateConversationProvider(id: id, providerID: "anthropic", modelName: "claude"))
        #expect(await store.updateConversationPreferences(
            id: id,
            verbosity: .detailed,
            reasoningEffort: .max,
            automationLevel: .autonomous
        ))
        #expect(await store.updateConversationPreferences(id: id, setReasoningEffortToNil: true))
        #expect(await store.updateProjectPath(for: [id, childID], projectPath: "/after"))

        let updated = try #require(await store.fetchConversation(id: id))
        #expect(updated.title == "Renamed")
        #expect(updated.preview == "latest answer")
        #expect(updated.lastMessageAt == lastMessageAt)
        #expect(updated.providerID == "anthropic")
        #expect(updated.modelName == "claude")
        #expect(updated.verbosity == .detailed)
        #expect(updated.reasoningEffort == nil)
        #expect(updated.automationLevel == .autonomous)
        #expect(updated.projectPath == "/after")
        #expect(await store.fetchConversation(id: childID)?.projectPath == "/after")

        let missingID = UUID()
        #expect(!(await store.updateTitle(id: missingID, title: "missing")))
        #expect(!(await store.updatePreview(id: missingID, preview: "missing")))
        #expect(!(await store.updateLastMessageAt(id: missingID, messageDate: lastMessageAt)))
        #expect(!(await store.updateConversationProvider(id: missingID, providerID: "missing", modelName: nil)))
        #expect(!(await store.updateProjectPath(for: [missingID], projectPath: nil)))
        #expect(!(await store.updateProjectPath(for: [], projectPath: nil)))
        #expect(!(await store.deleteConversations(ids: [])))
        #expect(!(await store.deleteConversations(ids: [missingID])))
    }

    @Test("ConversationManager delegates paged reads and caches only root summaries")
    @MainActor
    func managerFetchesPagesCountsAndRootCache() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let rootID = UUID()
        let childID = UUID()
        try await store.createConversation(id: rootID, title: "root", projectPath: "/project")
        try await store.createConversation(
            id: childID,
            title: "child",
            projectPath: "/project",
            parentConversationID: rootID
        )
        let manager = ConversationManager(store: store, dataDirectory: dir)

        let roots = await manager.fetchConversationPage(limit: 10)
        let all = await manager.fetchConversationPage(limit: 10, includingChildConversations: true)
        let projectConversations = await manager.fetchConversationPage(
            limit: 10,
            includingChildConversations: true,
            projectPath: "/project"
        )
        #expect(roots.map(\.id) == [rootID])
        #expect(Set(all.map(\.id)) == [rootID, childID])
        #expect(Set(projectConversations.map(\.id)) == [rootID, childID])
        #expect(await manager.conversationCount(projectPath: "/project") == 1)
        #expect(await manager.conversationCount(projectPath: "/project", includingChildConversations: true) == 2)
        #expect(await manager.conversationProjectCount() == 1)

        #expect(await manager.fetchConversation(id: childID)?.id == childID)
        #expect(manager.conversations.isEmpty)
        #expect(await manager.fetchConversation(id: rootID)?.id == rootID)
        #expect(manager.conversations.map(\.id) == [rootID])
        #expect(await manager.fetchConversation(id: rootID)?.id == rootID)
    }
}
