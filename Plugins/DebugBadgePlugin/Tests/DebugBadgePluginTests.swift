import Testing
import Foundation
@testable import DebugBadgePlugin

@Suite
@MainActor
struct DebugBadgePluginTests {
    @Test
    func pluginIdentityIsStable() {
        let plugin = DebugBadgePlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.debug-badge")
        #expect(plugin.order == 900)
        #expect(plugin.category == .development)
        #expect(!plugin.name.isEmpty)
    }
}
