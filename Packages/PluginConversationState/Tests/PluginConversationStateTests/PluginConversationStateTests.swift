import Testing
@testable import PluginConversationState

@Suite("PluginConversationState")
struct PluginConversationStateTests {
    @Test @MainActor
    func pluginMetadataIsStable() {
        let plugin = ConversationStatePlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.conversation-state")
        #expect(plugin.order == 10)
        #expect(plugin.metadata.policy == .alwaysOn)
    }
}
