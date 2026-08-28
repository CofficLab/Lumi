import Foundation
import ProviderConversationState
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

    @Test
    @MainActor
    func providerPublishesStateEvents() {
        let provider = ConversationStateProvider()
        let conversationID = UUID()
        var events: [ConversationStateEvent] = []
        let handle = provider.addConversationStateObserver { events.append($0) }

        provider.update(conversationID: conversationID, agentLoopState: .running)
        provider.remove(conversationID: conversationID)

        #expect(events == [.updated(conversationID), .removed(conversationID)])
        handle.cancel()
    }
}
