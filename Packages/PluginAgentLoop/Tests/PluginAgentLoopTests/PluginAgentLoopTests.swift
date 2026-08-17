import Testing
import Foundation
@testable import PluginAgentLoop

@MainActor
@Test func testPluginInitialization() async throws {
    let plugin = PluginAgentLoop()
    #expect(plugin.id == "com.coffic.lumi.plugin.agent-loop")
    #expect(plugin.order == 8)
}

@MainActor
@Test func testPluginMetadata() async throws {
    let plugin = PluginAgentLoop()
    let metadata = plugin.metadata
    #expect(metadata.name == "Custom Agent Loop")
    #expect(metadata.category == .chat)
}