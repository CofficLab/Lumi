import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// 大数据量下的存储层分页行为。
@MainActor
@Suite("MessageStore 大数据量分页")
struct MessageStoreScaleTests {
    private func makeStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageStoreScale-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    @Test("5000 条消息下分页查询耗时应保持有界")
    func paginationStaysBoundedAtScale() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()

        // 一次性插入 5000 条
        let insertStart = Date()
        for index in 0..<5000 {
            let message = Message(
                conversationID: conversationID,
                role: index.isMultiple(of: 2) ? .user : .assistant,
                content: "消息 \(index) " + String(repeating: "内容", count: 20),
                createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
            )
            try store.insertMessage(message)
        }
        let insertElapsed = Date().timeIntervalSince(insertStart)
        print("SCALE insert5000=\(insertElapsed)s")

        // 首屏分页
        let pageStart = Date()
        let page = store.fetchMessagePage(
            conversationId: conversationID,
            limit: 41,
            beforeMessageID: nil,
            includesToolMessages: false
        )
        let pageElapsed = Date().timeIntervalSince(pageStart)
        print("SCALE firstPage=\(pageElapsed)s count=\(page.count)")

        #expect(page.count == 41)
        // 首屏应是最新 41 条
        #expect(page.last?.content.contains("消息 4999") == true)

        // 游标翻页
        var cursor = page.first?.id
        var pages = 0
        let cursorStart = Date()
        while let current = cursor, pages < 100 {
            let earlier = store.fetchMessagePage(
                conversationId: conversationID,
                limit: 40,
                beforeMessageID: current,
                includesToolMessages: false
            )
            if earlier.isEmpty { break }
            cursor = earlier.first?.id
            pages += 1
        }
        let cursorElapsed = Date().timeIntervalSince(cursorStart)
        print("SCALE cursorPages=\(pages) elapsed=\(cursorElapsed)s")

        #expect(pages > 0)
        // 每页查询应是毫秒级（索引可用），不是全表扫描
        #expect(cursorElapsed < 5.0, "游标翻页 \(pages) 页耗时 \(cursorElapsed)s，疑似全表扫描")
    }

    @Test("hasEarlierMessages 在大数据量下是常数级查询")
    func hasEarlierIsBounded() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()
        for index in 0..<3000 {
            try store.insertMessage(Message(
                conversationID: conversationID,
                role: .user,
                content: "m\(index)",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
            ))
        }

        let start = Date()
        let has = store.hasEarlierMessages(
            conversationId: conversationID,
            beforeMessageID: nil,
            includesToolMessages: false
        )
        let elapsed = Date().timeIntervalSince(start)
        print("SCALE hasEarlier=\(elapsed)s has=\(has)")

        #expect(has)
        #expect(elapsed < 1.0, "hasEarlierMessages 耗时 \(elapsed)s")
    }
}
