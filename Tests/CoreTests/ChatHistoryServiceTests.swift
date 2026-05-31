#if canImport(XCTest)
import SwiftData
import XCTest
@testable import Lumi

final class ChatHistoryServiceTests: XCTestCase {
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
