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

    @Test
    func fetchesTokenUsageForSingleDayWithProviderAndModelFilters() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageStoreTokenUsageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try MessageStore(databaseRootURL: directory)
        let conversationID = UUID()
        let calendar = Calendar(identifier: .gregorian)
        let targetDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 29)))
        let sameDay = try #require(calendar.date(byAdding: .hour, value: 13, to: targetDay))
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: targetDay))

        _ = try await store.insertMessage(LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "openai response",
            createdAt: sameDay,
            providerID: "openai",
            modelName: "gpt-5",
            inputTokenCount: 10,
            outputTokenCount: 20
        ))
        _ = try await store.insertMessage(LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "metadata response",
            createdAt: sameDay.addingTimeInterval(60),
            providerID: "openai",
            modelName: "gpt-5",
            metadata: [
                LumiMessageTokenMetadata.inputKey: "3",
                LumiMessageTokenMetadata.outputKey: "7",
            ]
        ))
        _ = try await store.insertMessage(LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "anthropic response",
            createdAt: sameDay.addingTimeInterval(120),
            providerID: "anthropic",
            modelName: "claude",
            inputTokenCount: 5,
            outputTokenCount: 6
        ))
        _ = try await store.insertMessage(LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "next day response",
            createdAt: nextDay,
            providerID: "openai",
            modelName: "gpt-5",
            inputTokenCount: 100,
            outputTokenCount: 200
        ))

        let allUsage = await store.fetchTokenUsage(on: sameDay)
        #expect(allUsage.day == Calendar.current.startOfDay(for: sameDay))
        #expect(allUsage.inputTokens == 18)
        #expect(allUsage.outputTokens == 33)
        #expect(allUsage.totalTokens == 51)

        let openAIUsage = await store.fetchTokenUsage(on: sameDay, providerID: "openai")
        #expect(openAIUsage.inputTokens == 13)
        #expect(openAIUsage.outputTokens == 27)

        let filteredUsage = await store.fetchTokenUsage(on: sameDay, providerID: "openai", modelName: "gpt-5")
        #expect(filteredUsage.inputTokens == 13)
        #expect(filteredUsage.outputTokens == 27)

        let missingUsage = await store.fetchTokenUsage(on: sameDay, providerID: "openai", modelName: "gpt-4")
        #expect(missingUsage.totalTokens == 0)
    }
}
