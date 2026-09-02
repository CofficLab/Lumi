import Testing
@testable import PluginConversationStats

@MainActor
@Test func statisticsPackageCanBeImported() async throws {
    #expect(ConversationMessageCountPlugin().id == "com.coffic.lumi.plugin.conversation-message-count")
}
