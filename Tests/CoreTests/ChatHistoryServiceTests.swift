#if canImport(XCTest)
import SwiftData
import XCTest
@testable import Lumi

final class ChatHistoryServiceTests: XCTestCase {
    @MainActor
    func testLoadMessagesPageReportsMoreVisibleMessagesBeyondHiddenBatch() async throws {
        let service = try makeService()
        let conversation = service.createConversation(title: "history")
        let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

        let olderVisible = ChatMessage(
            id: UUID(),
            role: .user,
            conversationId: conversation.id,
            content: "Older visible message",
            timestamp: baseTimestamp
        )
        _ = service.saveMessage(olderVisible, to: conversation)

        for index in 1 ... 31 {
            let hidden = ChatMessage(
                id: UUID(),
                role: .tool,
                conversationId: conversation.id,
                content: "Hidden tool output \(index)",
                timestamp: baseTimestamp.addingTimeInterval(TimeInterval(index))
            )
            _ = service.saveMessage(hidden, to: conversation)
        }

        let newestVisible = ChatMessage(
            id: UUID(),
            role: .assistant,
            conversationId: conversation.id,
            content: "Newest visible message",
            timestamp: baseTimestamp.addingTimeInterval(40)
        )
        _ = service.saveMessage(newestVisible, to: conversation)

        let page = await service.loadMessagesPage(
            forConversationId: conversation.id,
            limit: 1
        )

        XCTAssertEqual(page.messages.map(\.content), ["Newest visible message"])
        XCTAssertTrue(page.hasMore)
    }

    @MainActor
    func testSaveMessagePreservesOriginalTimestampForHistoryOrdering() throws {
        let service = try makeService()
        let conversation = service.createConversation(title: "history")
        let originalTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let message = ChatMessage(
            id: UUID(),
            role: .user,
            conversationId: conversation.id,
            content: "Queued message",
            timestamp: originalTimestamp
        )

        let saved = service.saveMessage(message, to: conversation)
        let loaded = service.loadMessages(for: conversation)

        XCTAssertEqual(saved?.timestamp, originalTimestamp)
        XCTAssertEqual(loaded.first?.timestamp, originalTimestamp)
    }

    @MainActor
    func testMostPopularModelPreferencePreservesDelimiterInModelName() throws {
        let service = try makeService()
        let context = service.getContext()

        let first = Conversation(title: "first")
        first.providerId = "provider"
        first.model = "model|variant"
        context.insert(first)

        let second = Conversation(title: "second")
        second.providerId = "provider"
        second.model = "model|variant"
        context.insert(second)

        let third = Conversation(title: "third")
        third.providerId = "provider"
        third.model = "other"
        context.insert(third)

        try context.save()

        let preference = service.fetchMostPopularModelPreference()

        XCTAssertEqual(preference?.providerId, "provider")
        XCTAssertEqual(preference?.model, "model|variant")
    }

    @MainActor
    private func makeService() throws -> ChatHistoryService {
        let schema = DBConfig.getSchema()
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [config])
        return ChatHistoryService(
            llmService: LLMService(registry: LLMProviderRegistry()),
            modelContainer: container,
            reason: "test"
        )
    }
}
#endif
