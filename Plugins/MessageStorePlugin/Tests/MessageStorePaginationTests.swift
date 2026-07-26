import Foundation
import LumiKernel
import Testing
@testable import MessageStorePlugin

@Suite(.serialized)
struct MessageStorePaginationTests {
    @Test
    func fetchesLatestPageAndEarlierPageWithoutLoadingEverything() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageStorePaginationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try MessageStore(databaseRootURL: directory)
        let conversationID = UUID()
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        for index in 0..<15 {
            let message = LumiChatMessage(
                conversationID: conversationID,
                role: .user,
                content: "Message \(index)",
                createdAt: baseDate.addingTimeInterval(Double(index))
            )
            _ = try await store.insertMessage(message)
        }

        let latestPage = await store.fetchMessagePage(conversationId: conversationID, limit: 10)
        #expect(latestPage.count == 10)
        #expect(latestPage.first?.content == "Message 5")
        #expect(latestPage.last?.content == "Message 14")

        let pivotID = try #require(latestPage.first?.id)
        let earlierPage = await store.fetchMessagePage(
            conversationId: conversationID,
            limit: 10,
            beforeMessageID: pivotID
        )

        #expect(earlierPage.count == 5)
        #expect(earlierPage.first?.content == "Message 0")
        #expect(earlierPage.last?.content == "Message 4")
        #expect(await store.hasEarlierMessages(conversationId: conversationID, beforeMessageID: pivotID))

        let oldestEarlierID = try #require(earlierPage.first?.id)
        #expect(!(await store.hasEarlierMessages(conversationId: conversationID, beforeMessageID: oldestEarlierID)))
    }
}
