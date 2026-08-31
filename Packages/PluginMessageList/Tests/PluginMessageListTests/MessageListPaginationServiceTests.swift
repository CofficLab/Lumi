import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageList

@MainActor
@Suite("Message list pagination service")
struct MessageListPaginationServiceTests {
    @Test("loads bounded windows and walks older pages by cursor")
    func loadsBoundedWindowsAndEarlierPages() {
        let manager = DefaultMessageManager()
        let conversationID = UUID()

        for index in 0..<95 {
            manager.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: "m\(index)",
                    createdAt: Date(timeIntervalSince1970: TimeInterval(index))
                ),
                to: conversationID
            )
        }

        let pagination = MessageListPaginationService(pageSize: 40, maxRetainedCount: 300)
        let first = pagination.loadFirstPage(
            conversationID: conversationID,
            messageManager: manager
        )

        #expect(first.messages.count == 40)
        #expect(first.messages.first?.content == "m55")
        #expect(first.messages.last?.content == "m94")
        #expect(first.hasEarlierMessages)

        let middle = pagination.loadEarlier(
            conversationID: conversationID,
            messageManager: manager,
            currentFirstID: first.messages.first?.id,
            hasEarlier: first.hasEarlierMessages
        )
        #expect(middle?.earlier.count == 40)
        #expect(middle?.earlier.first?.content == "m15")
        #expect(middle?.earlier.last?.content == "m54")
        #expect(middle?.hasEarlierMessages == true)

        let oldest = pagination.loadEarlier(
            conversationID: conversationID,
            messageManager: manager,
            currentFirstID: middle?.earlier.first?.id,
            hasEarlier: middle?.hasEarlierMessages == true
        )
        #expect(oldest?.earlier.count == 15)
        #expect(oldest?.earlier.first?.content == "m0")
        #expect(oldest?.earlier.last?.content == "m14")
        #expect(oldest?.hasEarlierMessages == false)
    }
}
