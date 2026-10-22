import Foundation
import Testing
@testable import PluginConversationManager

/// 验证**存储层能查出无标题对话**。
///
/// 回填存量数据依赖这个查询：内存里的会话摘要只是一个有界窗口，历史遗留的
/// 无标题对话大概率不在其中，按 ID 直接查库才能覆盖全量。
///
/// 判定条件是「标题为空串」——`ConversationModel.title` 是非可选 `String`，
/// 且所有写入路径都会先 trim，库里不可能存在纯空白标题。
@Suite("存储层的无标题对话查询")
struct ConversationStoreUntitledQueryTests {

    private func makeStore() throws -> (ConversationStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-untitled-query-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = try ConversationStore(databaseRootURL: dir)
        return (store, dir)
    }

    /// 必须查出无标题的对话，且不得把有标题的对话带进来。
    @Test("存储层能查出无标题对话且排除有标题的对话")
    func findsOnlyUntitledConversations() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let untitled = UUID()
        let titled = UUID()
        try await store.createConversation(id: untitled, title: nil)
        try await store.createConversation(id: titled, title: "有标题")

        let ids = await store.untitledConversationIDs(limit: 100)

        #expect(ids.contains(untitled), "无标题对话应被查出")
        #expect(!ids.contains(titled), "有标题的对话不应被查出")
    }

    /// 纯空白标题与无标题等价：写入时会被 trim，落库就是空串，必须被查出。
    @Test("纯空白标题的对话也算无标题")
    func treatsWhitespaceOnlyTitleAsUntitled() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let blank = UUID()
        try await store.createConversation(id: blank, title: "   \n ")

        let ids = await store.untitledConversationIDs(limit: 100)
        #expect(ids.contains(blank))
    }

    /// 子代理对话不进列表，给它们补标题没有用户价值，必须排除。
    @Test("排除子代理对话")
    func excludesChildConversations() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let child = UUID()
        try await store.createConversation(id: child, title: nil, parentConversationID: UUID())

        let ids = await store.untitledConversationIDs(limit: 100)
        #expect(!ids.contains(child), "子代理对话不进列表，不应参与回填")
    }

    /// 上限必须生效：回填是「启动时做一点」的工作，不是一次性的全库重写。
    @Test("遵守数量上限")
    func respectsLimit() async throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        for _ in 0..<5 {
            try await store.createConversation(id: UUID(), title: nil)
        }

        let ids = await store.untitledConversationIDs(limit: 2)
        #expect(ids.count == 2, "应最多返回 2 个，实际 \(ids.count)")

        #expect(await store.untitledConversationIDs(limit: 0).isEmpty)
    }
}
