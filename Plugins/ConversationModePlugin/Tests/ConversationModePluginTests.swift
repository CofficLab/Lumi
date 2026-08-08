import Testing
import LumiKernel
@testable import ConversationModePlugin

@MainActor
@Test func pluginMetadata() {
    let plugin = ConversationModePlugin()
    #expect(plugin.id.isEmpty == false)
    #expect(plugin.name.isEmpty == false)
    #expect(plugin.order == 84)
    #expect(plugin.policy == .alwaysOn)
}
