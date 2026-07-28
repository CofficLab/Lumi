import Testing
import LumiKernel
@testable import ChatModePlugin

@MainActor
@Test func pluginMetadata() {
    let plugin = ChatModePlugin()
    #expect(plugin.id.isEmpty == false)
    #expect(plugin.name.isEmpty == false)
    #expect(plugin.order == 84)
    #expect(plugin.policy == .alwaysOn)
}
