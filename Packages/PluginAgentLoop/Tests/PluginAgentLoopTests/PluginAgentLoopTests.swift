import Testing
import Foundation
@testable import PluginAgentLoop

@Test func testPluginInitialization() async throws {
    let plugin = PluginAgentLoop()
    #expect(plugin.id == "com.coffic.lumi.plugin.agent-loop")
    #expect(plugin.order == 1)
}

@Test func testPluginMetadata() async throws {
    let plugin = PluginAgentLoop()
    let metadata = plugin.metadata
    #expect(metadata.name == "PluginAgentLoop")
    #expect(metadata.category == .chat)
}
