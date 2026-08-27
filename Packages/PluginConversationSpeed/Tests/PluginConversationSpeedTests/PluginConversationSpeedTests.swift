import Testing
@testable import PluginConversationSpeed

@Test func speedPluginInstantiates() async throws {
    let plugin = ConversationSpeedPlugin()
    #expect(plugin.id == "com.coffic.lumi.plugin.conversation-speed")
}
