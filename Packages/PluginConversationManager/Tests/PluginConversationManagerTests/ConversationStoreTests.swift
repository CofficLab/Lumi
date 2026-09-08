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
}
