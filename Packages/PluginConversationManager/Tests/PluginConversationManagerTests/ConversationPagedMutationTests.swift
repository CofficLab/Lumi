import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

/// Regression coverage for issue #965: conversations that reach the UI through
/// pagination must be operable even when they are not in the bounded cache.
@MainActor
@Suite("分页会话的可操作性")
struct ConversationPagedMutationTests {

    private func makeStore() throws -> (ConversationStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-conversation-paged-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (try ConversationStore(databaseRootURL: dir), dir)
    }

    private func waitUntil(_ condition: @escaping () async -> Bool) async -> Bool {
        for _ in 0..<100 {
            if await condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return false
    }

    @Test("未缓存的会话也能删除")
    func deletesUncachedConversation() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = ConversationManager(store: store, dataDirectory: dir)
        let id = UUID()
        try await store.createConversation(id: id, title: "历史会话")
        #expect(manager.conversations.isEmpty)

        manager.deleteConversation(id: id)

        let deleted = await waitUntil { await store.fetchConversation(id: id) == nil }
        #expect(deleted, "未缓存的会话没有被删除")
    }

    @Test("未缓存的会话也能改名")
    func renamesUncachedConversation() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = ConversationManager(store: store, dataDirectory: dir)
        let id = UUID()
        try await store.createConversation(id: id, title: "历史会话")

        #expect(manager.updateConversationTitle("新标题", for: id))

        let renamed = await waitUntil { await store.fetchConversation(id: id)?.title == "新标题" }
        #expect(renamed, "未缓存会话的标题没有落库")
    }

    @Test("未缓存的会话也能保存偏好")
    func persistsPreferencesForUncachedConversation() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = ConversationManager(store: store, dataDirectory: dir)
        let id = UUID()
        try await store.createConversation(id: id, title: "历史会话")

        manager.setVerbosity(.brief, for: id)
        let verbositySaved = await waitUntil {
            await store.fetchConversation(id: id)?.verbosity == .brief
        }
        #expect(verbositySaved, "未缓存会话的详细程度没有落库")

        manager.setReasoningEffort(.high, for: id)
        let reasoningSaved = await waitUntil {
            await store.fetchConversation(id: id)?.reasoningEffort == .high
        }
        #expect(reasoningSaved, "未缓存会话的推理强度没有落库")
    }

    @Test("选中分页会话后会补载标题")
    func selectingPagedConversationBackfillsTitle() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = ConversationManager(store: store, dataDirectory: dir)
        let id = UUID()
        try await store.createConversation(id: id, title: "历史会话")
        #expect(manager.conversations.isEmpty)

        manager.selectConversation(id: id)

        #expect(manager.currentTitle == "No conversation")
        let backfilled = await waitUntil { manager.currentTitle == "历史会话" }
        #expect(backfilled, "选中未缓存会话后标题没有恢复")
    }

    @Test("分页结果会进入缓存")
    func pagedResultsEnterCache() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = ConversationManager(store: store, dataDirectory: dir)
        let id = UUID()
        try await store.createConversation(id: id, title: "历史会话")

        let page = await manager.fetchConversationPage(limit: 10)

        #expect(page.count == 1)
        #expect(manager.conversations.contains { $0.id == id })
    }
}
