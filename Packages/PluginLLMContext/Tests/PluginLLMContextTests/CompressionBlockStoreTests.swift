import Foundation
import Testing

@testable import PluginLLMContext

struct CompressionBlockStoreTests {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CompressionBlockStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func block(
        conversationID: UUID,
        tier: Int = 1,
        sourceMessageIDs: [UUID] = [],
        sourceBlockIDs: [UUID] = [],
        active: Bool = true,
        summary: String = "摘要"
    ) -> CompressionBlock {
        CompressionBlock(
            conversationID: conversationID,
            tier: tier,
            summary: summary,
            sourceMessageIDs: sourceMessageIDs,
            sourceBlockIDs: sourceBlockIDs,
            coveredThroughMessageID: UUID(),
            providerID: "provider",
            modelName: "model",
            estimatedTokens: 42,
            active: active
        )
    }

    @Test("tier-1 块连同源消息 ID 列表往返一致")
    func roundTripTier1() async throws {
        let store = try CompressionBlockStore(directory: makeDirectory())
        let conversationID = UUID()
        let ids = [UUID(), UUID(), UUID()]
        let original = block(conversationID: conversationID, sourceMessageIDs: ids)
        try await store.save([original])

        let loaded = try await store.load(conversationID: conversationID)
        #expect(loaded == [original])
        #expect(loaded.first?.sourceMessageIDs == ids)
    }

    @Test("tier-2 块连同源块 ID 列表往返一致")
    func roundTripTier2() async throws {
        let store = try CompressionBlockStore(directory: makeDirectory())
        let conversationID = UUID()
        let childIDs = [UUID(), UUID()]
        let original = block(conversationID: conversationID, tier: 2, sourceBlockIDs: childIDs)
        try await store.save([original])

        let loaded = try await store.load(conversationID: conversationID)
        #expect(loaded.first?.sourceBlockIDs == childIDs)
        #expect(loaded.first?.tier == 2)
    }

    @Test("同 id 再次保存是更新而非重复插入（折叠停用）")
    func upsertDeactivates() async throws {
        let store = try CompressionBlockStore(directory: makeDirectory())
        let conversationID = UUID()
        let original = block(conversationID: conversationID)
        try await store.save([original])

        var deactivated = original
        deactivated.active = false
        try await store.save([deactivated])

        let loaded = try await store.load(conversationID: conversationID)
        #expect(loaded.count == 1)
        #expect(loaded.first?.active == false)
    }

    @Test("读取包含停用块，供血缘回溯")
    func loadIncludesInactive() async throws {
        let store = try CompressionBlockStore(directory: makeDirectory())
        let conversationID = UUID()
        let active = block(conversationID: conversationID, tier: 2)
        let inactive = block(conversationID: conversationID, tier: 1, active: false)
        try await store.save([active, inactive])

        let loaded = try await store.load(conversationID: conversationID)
        #expect(loaded.count == 2)
        #expect(loaded.contains { !$0.active })
    }

    @Test("remove 只清理目标会话的块")
    func removeScopedToConversation() async throws {
        let store = try CompressionBlockStore(directory: makeDirectory())
        let keep = UUID()
        let drop = UUID()
        try await store.save([block(conversationID: keep), block(conversationID: drop)])

        try await store.remove(conversationID: drop)

        #expect(try await store.load(conversationID: drop).isEmpty)
        #expect(try await store.load(conversationID: keep).count == 1)
    }

    @Test("重建 store 后从磁盘恢复块")
    func survivesRecreation() async throws {
        let directory = makeDirectory()
        let conversationID = UUID()
        let original = block(conversationID: conversationID, summary: "持久化摘要")
        let first = try CompressionBlockStore(directory: directory)
        try await first.save([original])

        let second = try CompressionBlockStore(directory: directory)
        let loaded = try await second.load(conversationID: conversationID)
        #expect(loaded == [original])
        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(CompressionBlockStore.databaseFileName).path
        ))
    }
}