import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

/// 按项目取会话 ID。
///
/// 「本项目近 30 天」这类统计需要一组会话 ID：消息表里只有会话 ID，
/// 项目归属存在会话存储里。这组用例守住这条映射的三条语义：
/// 1. 只返回该项目的会话；
/// 2. `updatedSince` 把集合限制在活动窗口内；
/// 3. 项目下没有会话时返回空数组（而不是 nil 或全部）。
@Suite("ConversationStore 项目会话 ID")
@MainActor
struct ConversationStoreProjectIDTests {
    private func makeStore() throws -> (store: ConversationStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-conversation-project-ids-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try ConversationStore(databaseRootURL: directory), directory)
    }

    @Test("只返回该项目的会话 ID")
    func returnsOnlyProjectConversations() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let mine = UUID()
        let other = UUID()
        try await store.createConversation(id: mine, title: "A", projectPath: "/tmp/project-a")
        try await store.createConversation(id: other, title: "B", projectPath: "/tmp/project-b")

        let ids = await store.conversationIDs(projectPath: "/tmp/project-a")
        #expect(ids == [mine.uuidString])
    }

    @Test("活动窗口把集合限制在窗口内")
    func limitsToTheActivityWindow() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let recent = UUID()
        let old = UUID()
        let now = Date()
        try await store.createConversation(
            id: recent, title: "recent", createdAt: now, projectPath: "/tmp/project-a"
        )
        try await store.createConversation(
            id: old, title: "old", createdAt: now.addingTimeInterval(-86_400 * 10), projectPath: "/tmp/project-a"
        )

        let ids = await store.conversationIDs(
            projectPath: "/tmp/project-a",
            updatedSince: now.addingTimeInterval(-86_400)
        )
        #expect(ids == [recent.uuidString], "窗口之外才更新的会话不该进入集合")
    }

    @Test("项目下没有会话时返回空数组")
    func emptyProjectReturnsEmptyArray() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        try await store.createConversation(id: UUID(), title: "A", projectPath: "/tmp/project-a")

        let ids = await store.conversationIDs(projectPath: "/tmp/project-empty")
        #expect(ids.isEmpty)
    }
}
