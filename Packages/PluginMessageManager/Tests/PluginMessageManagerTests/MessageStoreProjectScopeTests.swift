import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// 按会话集合过滤的日统计。
///
/// 「本项目近 30 天」这类统计需要「哪些消息属于这个项目」这个判定。消息表里
/// 只有会话 ID，项目归属存在会话存储里，因此过滤条件是一组会话 ID。
///
/// 这组用例守住三条最容易出错的语义：
/// 1. 空集合 = 该范围内没有会话（**不是**「统计全部」）；
/// 2. `nil` = 不限会话；
/// 3. 会话数超过 SQLite 变量上限时按块查询再合并，结果与一次性查询一致。
@Suite("MessageStore 项目维度日统计")
struct MessageStoreProjectScopeTests {
    private func makeStore() throws -> (store: MessageStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageStoreProjectScope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    @Test("会话过滤只统计指定会话的消息")
    func filtersByConversation() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let mine = UUID()
        let other = UUID()
        let day = Calendar.current.startOfDay(for: Date())

        try store.insertMessage(Message(
            conversationID: mine, role: .user, content: "a", createdAt: day, inputTokenCount: 3
        ))
        try store.insertMessage(Message(
            conversationID: mine, role: .assistant, content: "b", createdAt: day, inputTokenCount: 5
        ))
        try store.insertMessage(Message(
            conversationID: other, role: .user, content: "c", createdAt: day, inputTokenCount: 7
        ))

        let counts = store.dailyAggregate(
            since: .distantPast,
            excludingIDs: [],
            countTokens: false,
            conversationIDs: [mine.uuidString]
        )
        #expect(counts[day] == 2, "别的会话的消息不该被算进来")

        let tokens = store.dailyAggregate(
            since: .distantPast,
            excludingIDs: [],
            countTokens: true,
            conversationIDs: [mine.uuidString]
        )
        #expect(tokens[day] == 8)
    }

    @Test("空会话集合返回空结果，而不是退化成全量")
    func emptyConversationSetMeansEmpty() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let day = Calendar.current.startOfDay(for: Date())
        try store.insertMessage(Message(
            conversationID: UUID(), role: .user, content: "a", createdAt: day, inputTokenCount: 3
        ))

        let counts = store.dailyAggregate(
            since: .distantPast,
            excludingIDs: [],
            countTokens: false,
            conversationIDs: []
        )
        #expect(counts.isEmpty, "空会话集合代表该范围内没有会话，绝不能退化成全量统计")
    }

    @Test("nil 表示不限会话")
    func nilConversationSetMeansUnrestricted() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let day = Calendar.current.startOfDay(for: Date())
        try store.insertMessage(Message(
            conversationID: UUID(), role: .user, content: "a", createdAt: day, inputTokenCount: 3
        ))
        try store.insertMessage(Message(
            conversationID: UUID(), role: .user, content: "b", createdAt: day, inputTokenCount: 3
        ))

        let counts = store.dailyAggregate(
            since: .distantPast,
            excludingIDs: [],
            countTokens: false,
            conversationIDs: nil
        )
        #expect(counts[day] == 2)
    }

    @Test("会话数超过单块上限时按块合并，结果与一次性查询一致")
    func chunksLargeConversationSets() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let day = Calendar.current.startOfDay(for: Date())
        // 单块上限是 200；这里造 250 个会话，必然要分块。
        var ids: [String] = []
        for index in 0..<250 {
            let conversationID = UUID()
            ids.append(conversationID.uuidString)
            try store.insertMessage(Message(
                conversationID: conversationID, role: .user, content: "m\(index)",
                createdAt: day, inputTokenCount: 2
            ))
        }
        // 一个不在集合里的会话。
        try store.insertMessage(Message(
            conversationID: UUID(), role: .user, content: "outside", createdAt: day, inputTokenCount: 2
        ))

        let counts = store.dailyAggregate(
            since: .distantPast,
            excludingIDs: [],
            countTokens: false,
            conversationIDs: ids
        )
        #expect(counts[day] == 250, "分块查询合并后的总数必须与一次性查询一致")

        let tokens = store.dailyAggregate(
            since: .distantPast,
            excludingIDs: [],
            countTokens: true,
            conversationIDs: ids
        )
        #expect(tokens[day] == 500)
    }
}
